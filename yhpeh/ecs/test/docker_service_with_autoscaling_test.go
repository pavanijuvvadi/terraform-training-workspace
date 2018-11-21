package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func elbDockerServiceWithAutoScalingTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-autoscaling")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terraform.InitAndApply(t, terratestOptions)

	// TODO: hit the ECS Service with considerable traffic until that triggers an auto scaling event and then
	// verify that the number of ECS Tasks for the service has gone up.
}

// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func albDockerServiceWithAutoScalingTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-alb-autoscaling")

	terratestOptions := createAlbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terraform.InitAndApply(t, terratestOptions)

	// TODO: hit the ECS Service with considerable traffic until that triggers an auto scaling event and then
	// verify that the number of ECS Tasks for the service has gone up.
}
