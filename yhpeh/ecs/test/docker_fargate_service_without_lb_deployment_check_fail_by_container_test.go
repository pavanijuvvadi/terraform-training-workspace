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
// 2. Deploy a Docker container without a Load Balancer, with deployment checks on
// 3. Verify the deployment checks run and apply completes
// 4. Verify we can connect to the Docker container via one of the instances in the Fargate cluster
// 5. Deploy a Docker container that will fail on it
// 6. Verify deployment check detects the failure
// 7. Verify we can not connect to the Docker container via one of the instances in the Fargate cluster
func TestDockerFargateServiceWithoutlbDeploymentCheckFailByContainer(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-without-lb")
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
			url, _ := getUrlFromEcsCluster(t, terratestOptions, randomRegion)
			return testUrl(t, url, expectedServerText, urlGetRetries)
		},
	)
}

// Test that we can skip deployment checks
func TestDockerFargateServiceWithoutlbDeploymentSkipCheck(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-without-lb")
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
