package test

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container on it
// 3. Deploy a new version of that container as a canary
// 4. Deploy the new version across the rest of the cluster
// 5. Do all of this without downtime
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func elbDockerServiceWithCanaryDeploymentTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-canary-deployment")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	originalServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	canaryServerText := fmt.Sprintf("%s canary deploy", uniqueId)
	fullRollOutServerText := fmt.Sprintf("%s full roll out", uniqueId)

	mustDoContainerDeployment(t, terratestOptions, originalServerText)
	url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_ELB_DNS_NAME)
	testContainerUrl(t, url, originalServerText, TEST_S3_FILE_TEXT, 10)

	stopChecking := make(chan bool, 1)
	defer func() {
		stopChecking <- true
	}()

	continuouslyCheckUrl(t, url, stopChecking)
	testCanaryDeployment(t, url, terratestOptions, originalServerText, canaryServerText, TEST_S3_FILE_TEXT)
	testFullRollOut(t, url, terratestOptions, fullRollOutServerText, TEST_S3_FILE_TEXT)
}

// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func albDockerServiceWithCanaryDeploymentTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb-canary")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	originalServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	canaryServerText := fmt.Sprintf("%s canary deploy", uniqueId)
	fullRollOutServerText := fmt.Sprintf("%s full roll out", uniqueId)

	mustDoContainerDeployment(t, terratestOptions, originalServerText)
	url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
	testContainerUrl(t, url, originalServerText, TEST_S3_FILE_TEXT, 10)

	stopChecking := make(chan bool, 1)
	defer func() {
		stopChecking <- true
	}()

	continuouslyCheckUrl(t, url, stopChecking)
	testCanaryDeployment(t, url, terratestOptions, originalServerText, canaryServerText, TEST_S3_FILE_TEXT)
	testFullRollOut(t, url, terratestOptions, fullRollOutServerText, TEST_S3_FILE_TEXT)
}

// Deploy the new Docker image version as a canary and test that as we hit the ELB, we occasionally get the canary
// text, and occasionally the original server text
func testCanaryDeployment(
	t *testing.T,
	url string,
	terratestOptions *terraform.Options,
	originalServerText,
	canaryServerText string,
	s3Text string,
) {
	terratestOptions.Vars["canary_server_text"] = canaryServerText
	terratestOptions.Vars["desired_number_of_canary_tasks_to_run"] = 1

	terraform.Apply(t, terratestOptions)

	// Make sure we see the canary server text at least once
	expectedCanaryServerText := formatServerTextToMatchExampleDockerImage(canaryServerText, s3Text)
	if err := testUrlWithCanary(t, url, expectedCanaryServerText); err != nil {
		t.Fatalf("Failed to test ELB URL: %s\n", err.Error())
	}

	// Make sure we see the original server text at least once
	expectedOriginalServerText := formatServerTextToMatchExampleDockerImage(originalServerText, s3Text)
	if err := testUrlWithCanary(t, url, expectedOriginalServerText); err != nil {
		t.Fatalf("Failed to test ELB URL: %s\n", err.Error())
	}
}

func testUrlWithCanary(t *testing.T, url string, expectedServerText string) error {
	retries := 300
	sleepBetweenRetries := 1 * time.Second

	return http_helper.HttpGetWithRetryE(t, url, 200, expectedServerText, retries, sleepBetweenRetries)
}

// Deploy the new Docker image version across the cluster, undeploy the canary, and test that after the rollout is
// complete, when we hit the ELB, we always get the final roll out text and not the original or canary server text
func testFullRollOut(
	t *testing.T,
	url string,
	terratestOptions *terraform.Options,
	fullRollOutServerText string,
	s3Text string,
) {
	terratestOptions.Vars["desired_number_of_canary_tasks_to_run"] = 0
	terratestOptions.Vars["server_text"] = fullRollOutServerText

	terraform.Apply(t, terratestOptions)

	// Sleep for a minute, then apply again to workaround a bug in terraform 11 where outputs are throwing an error
	// in what looks like an eventual consistency scenario
	time.Sleep(time.Minute)

	terraform.Apply(t, terratestOptions)

	// Check that the new ECS Task has appeared at least once in the cluster.
	expectedFullRollOutServerText := formatServerTextToMatchExampleDockerImage(fullRollOutServerText, s3Text)
	if err := testUrlWithCanary(t, url, expectedFullRollOutServerText); err != nil {
		t.Fatalf("Failed to test ELB URL: %s\n", err.Error())
	}

	// Wait for a bit longer. We do this because we can't be sure exactly how long it'll take to roll out the
	// new ECS Task across the entire cluster. Hopefully, once the first one has appeared, it doesn't take more
	// than a few minutes for all the others to be fully deployed.
	time.Sleep(5 * time.Minute)

	// Now make a ton of requests to the ELB and ensure that *only* the new ECS Task is responding
	if err := testUrlAlwaysReturnsExpectedText(t, url, expectedFullRollOutServerText); err != nil {
		t.Fatalf("Failed to test ELB after full rollout: %v", err)
	}
}
