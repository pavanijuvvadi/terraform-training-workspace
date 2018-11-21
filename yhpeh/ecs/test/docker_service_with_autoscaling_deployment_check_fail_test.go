package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a version of the docker container, with deployment checks on
// 3. Verify the deployment checks run and apply completes
// 4. Connect to the Load Balancer and verify the deployed container is accessible
// 5. Deploy a broken container
// 6. Verify deployment check detects the failure
// 7. Connect to the Load Balancer and verify the deployed container is not accessible
// 8. Deploy the same broken container with deployment checks off.
// 9. Verify the deployment checks do not run and apply completes successfully
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func elbDockerServiceWithAutoScalingDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-autoscaling")

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

// Same as above test except test with ALB.
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func albDockerServiceWithAutoScalingDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb-autoscaling")

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
