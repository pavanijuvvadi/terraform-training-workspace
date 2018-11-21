package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

// Test that we can:
//
// 1. Create a Fargate cluster
// 2. Deploy a Docker container behind an Application Load Balancer, with deployment checks on
// 3. Verify the deployment checks run and apply completes
// 4. Connect to the Load Balancer and verify it is accessible
// 5. Deploy a Docker container that will fail on it
// 6. Verify deployment check detects the failure
// 7. Connect to the Load Balancer and verify it is inaccessible
func TestDockerFargateServiceWithAlbDeploymentCheckFailByContainer(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-with-alb")
	logger.Logf(t, "path %s\n", terraformModulePath)

	uniqueId := random.UniqueId()
	randomRegion := getRandomFargateSupportedRegion(t)
	terratestOptions := createFargateTerratestOptions(t, uniqueId, randomRegion, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	// Use 7 mins for deployment check, which is sufficient for these examples
	terratestOptions.Vars["deployment_check_timeout_seconds"] = FARGATE_FAILURE_CHECK_TIMEOUT_SECONDS
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
}

// Same as TestDockerFargateServiceWithAlbDeploymentCheckFailByContainer,
// except fail in a way such that it will pass the active task test but not the
// loadbalancer check.
func TestDockerFargateServiceWithAlbDeploymentCheckFailByContainerApp(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-with-alb")
	logger.Logf(t, "path %s\n", terraformModulePath)

	uniqueId := random.UniqueId()
	randomRegion := getRandomFargateSupportedRegion(t)
	terratestOptions := createFargateTerratestOptions(t, uniqueId, randomRegion, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

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

// Test that we can skip the deployment check
func TestDockerFargateServiceWithAlbDeploymentCheckSkip(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-with-alb")
	logger.Logf(t, "path %s\n", terraformModulePath)

	uniqueId := random.UniqueId()
	randomRegion := getRandomFargateSupportedRegion(t)
	terratestOptions := createFargateTerratestOptions(t, uniqueId, randomRegion, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	doSkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
	)
}
