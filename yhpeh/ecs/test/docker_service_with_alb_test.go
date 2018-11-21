package test

import (
	"fmt"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

const OUTPUT_SERVICE_DNS_NAME = "service_dns_name"

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container on it
// 3. Deploy a new version of that container
// 4. The switch from the old container to the new container happens without downtime
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithAlbContainerRedeployTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	initialDeployServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	redeployServerText := fmt.Sprintf("%s redeploy", uniqueId)

	mustDoContainerDeployment(t, terratestOptions, initialDeployServerText)
	url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DNS_NAME)
	testContainerUrl(t, url, initialDeployServerText, TEST_S3_FILE_TEXT, 10)

	stopChecking := make(chan bool, 1)
	defer func() {
		stopChecking <- true
	}()
	continuouslyCheckUrl(t, url, stopChecking)

	mustDoContainerDeployment(t, terratestOptions, redeployServerText)
	testContainerUrl(t, url, redeployServerText, TEST_S3_FILE_TEXT, 10)
}
