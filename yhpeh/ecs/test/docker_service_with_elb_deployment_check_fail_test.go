package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container on it, with deployment checks on
// 3. Verify the deployment checks run and apply completes
// 4. Connect to the Load Balancer and verify it is accessible
// 5. Deploy a broken docker container on it
// 6. Verify deployment check detects the failure
// 7. Connect to the Load Balancer and verify the new container is inaccessible
// 8. Deploy the same broken docker container on it with deployment checks off
// 9. Verify the deployment checks do not run and apply completes
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithElbContainerDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-elb")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	doFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
		fixContainerFailingOnBoot,
		func(expectedServerText string, urlGetRetries int) error {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_ELB_DNS_NAME)
			return testUrl(t, url, expectedServerText, urlGetRetries)
		},
	)
	doSkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
	)
}