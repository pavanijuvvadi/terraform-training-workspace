package test

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
)

// Test that we can:
//
// 1. Create a Fargate cluster
// 2. Deploy a Docker container on it without a Load Balancer
// 3. Connect to the Docker container via one of the instances in the Fargate cluster
func TestDockerFargateServiceWithNlb(t *testing.T) {
	t.Parallel()

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
	terraformModulePath := filepath.Join(testFolder, "docker-fargate-service-with-nlb")
	logger.Logf(t, "path %s\n", terraformModulePath)

	uniqueId := random.UniqueId()
	randomRegion := getRandomFargateSupportedRegion(t)
	terratestOptions := createFargateTerratestOptions(t, uniqueId, randomRegion, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terraform.InitAndApply(t, terratestOptions)

	url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)

	http_helper.HttpGetWithRetry(t, url, 200, "Hello world!", 10, 60*time.Second)
}
