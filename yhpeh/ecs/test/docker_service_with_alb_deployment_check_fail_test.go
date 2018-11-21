package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a docker container on it behind an Application Load Balancer, with deployment checks on
// 3. Verify the deployment checks run and apply completes
// 4. Verify we can access the service through the load balancer
// 5. Deploy a docker container on it that will fail
// 6. Verify deployment check detects the failure
// 7. Verify the new docker container is inaccessible from the load balancer
// 8. Deploy the same broken container, but with deployment checks off.
// 9. Verify the deployment checks do not run and apply completes successfully
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithAlbContainerDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	doFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
		fixContainerFailingOnBoot,
		func(expectedServerText string, urlGetRetries int) error {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
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

// Same as dockerServiceWithAlbContainerDeploymentCheckFailByContainerTest,
// except fail in a way such that it will pass the active task test but not the
// loadbalancer check.
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithAlbContainerDeploymentCheckFailByContainerAppTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	doFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailRequests,
		fixContainerFailingRequests,
		func(expectedServerText string, urlGetRetries int) error {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
			return testUrl(t, url, expectedServerText, urlGetRetries)
		},
	)
}

// Same as dockerServiceWithAlbContainerDeploymentCheckFailByContainerTest,
// except fail in a way such that the container does not
// actually get deployed due to lack of available resources.
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithAlbContainerDeploymentCheckFailByMemoryTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	// Use 5 mins for deployment check, which is sufficient for these examples
	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	doFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailByMemory,
		fixContainerFailingByMemory,
		func(expectedServerText string, urlGetRetries int) error {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
			return testUrl(t, url, expectedServerText, urlGetRetries)
		},
	)
}
