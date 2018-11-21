package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a docker container on it
// 3. Deploy a canary container, with deployment checks on
// 4. Verify the deployment checks run and apply completes
// 5. Connect to the Load Balancer and verify we get the canary text
// 6. Deploy a broken canary container
// 7. Verify deployment check detects the failure
// 8. Connect to the Load Balancer and verify we never get the new canary text
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func elbDockerServiceWithCanaryDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-canary-deployment")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	doFailureTestingWithCanary(
		t,
		terratestOptions,
		uniqueId,
		causeCanaryContainerToFailOnBoot,
		fixCanaryContainerFailingOnBoot,
		func() (string, error) {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_ELB_DNS_NAME)
			return url, nil
		},
	)
}

// Same as above test except test with ALB.
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func albDockerServiceWithCanaryDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb-canary")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	doFailureTestingWithCanary(
		t,
		terratestOptions,
		uniqueId,
		causeCanaryContainerToFailOnBoot,
		fixCanaryContainerFailingOnBoot,
		func() (string, error) {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
			return url, nil
		},
	)
}

// Test that we can skip the deployment check on the canary services.
func elbDockerServiceWithCanaryDeploymentCheckSkip(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-canary-deployment")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	doCanarySkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeCanaryContainerToFailOnBoot,
		func() (string, error) {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_ELB_DNS_NAME)
			return url, nil
		},
	)
}

// Test that we can skip the deployment check on the canary services.
func albDockerServiceWithCanaryDeploymentCheckSkip(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb-canary")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	doCanarySkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeCanaryContainerToFailOnBoot,
		func() (string, error) {
			url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
			return url, nil
		},
	)
}
