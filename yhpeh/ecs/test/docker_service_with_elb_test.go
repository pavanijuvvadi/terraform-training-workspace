package test

import (
	"fmt"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

const OUTPUT_ELB_DNS_NAME = "elb_dns_name"

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container on it
// 3. Deploy a new version of that container
// 4. The switch from the old container to the new container happens without downtime
// 5. Deploy a new version of the ECS cluster
// 6. The switch from the old ECS cluster to the new cluster happens without downtime
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithElbContainerRedeployTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-elb")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	initialDeployServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	redeployServerText := fmt.Sprintf("%s redeploy", uniqueId)

	// Do initial deployment of ECS Tasks
	mustDoContainerDeployment(t, terratestOptions, initialDeployServerText)
	url := getUrlFromTerraformOutputVal(t, terratestOptions, OUTPUT_ELB_DNS_NAME)
	testContainerUrl(t, url, initialDeployServerText, TEST_S3_FILE_TEXT, 10)

	// Start checking the ELB to make sure there is no downtime
	stopChecking := make(chan bool, 1)
	defer func() {
		stopChecking <- true
	}()
	continuouslyCheckUrl(t, url, stopChecking)

	// Deploy update to ECS Tasks
	mustDoContainerDeployment(t, terratestOptions, redeployServerText)
	testContainerUrl(t, url, redeployServerText, TEST_S3_FILE_TEXT, 10)

	// Deploy update to ECS Instances
	terratestOptions.Vars["user_data_text"] = uniqueId
	mustDoContainerDeployment(t, terratestOptions, redeployServerText)
	testContainerUrl(t, url, redeployServerText, TEST_S3_FILE_TEXT, 10)

	// Run the roll-out-ecs-cluster-update.py script to roll out the update to the ECS Instances
	doEcsClusterRollout(t, terratestOptions)
}
