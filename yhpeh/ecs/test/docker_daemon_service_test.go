package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Basic smoke test to make sure the docker-daemon-service example applies cleanly
// We use the `deploy-ecs-task` example to create the ECS cluster before
// running `docker-daemon-service`.
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerDaemonServiceTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	ecsClusterTerraformModulePath := filepath.Join(testFolder, "deploy-ecs-task")
	daemonServiceTerraformModulePath := filepath.Join(testFolder, "docker-daemon-service")

	ecsClusterTerratestOptions := createBaseDeployEcsTaskTerratestOptions(t, uniqueId, amiId, ecsClusterTerraformModulePath, randomRegion)
	defer terraform.Destroy(t, ecsClusterTerratestOptions)

	ecsClusterTerratestOptions.Vars["docker_image_command"] = []string{"sleep", "10"}
	terraform.InitAndApply(t, ecsClusterTerratestOptions)
	ecsClusterArn := getRequiredTerraformOutputVal(t, ecsClusterTerratestOptions, "ecs_cluster_arn")

	daemonServiceTerratestOptions := createDaemonServiceTerratestOptions(t, uniqueId, amiId, randomRegion, daemonServiceTerraformModulePath, ecsClusterArn)
	defer terraform.Destroy(t, daemonServiceTerratestOptions)

	terraform.InitAndApply(t, daemonServiceTerratestOptions)
}

// Test that we can:
//
// 1. Create a cluster
// 2. Create a daemon service with a container that will fail on boot, with deployment checks off
// 3. Verify the deployment checks do not run and apply completes
// 4. Apply with deployment checks on
// 5. Verify deployment check detects the failure
// 6. Fix the failing container to run successfully
// 7. Verify the apply is succesful and the deployment check passes
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerDaemonServiceDeploymentCheckFailByContainerTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	ecsClusterTerraformModulePath := filepath.Join(testFolder, "deploy-ecs-task")
	daemonServiceTerraformModulePath := filepath.Join(testFolder, "docker-daemon-service")

	ecsClusterTerratestOptions := createBaseDeployEcsTaskTerratestOptions(t, uniqueId, amiId, ecsClusterTerraformModulePath, randomRegion)
	defer terraform.Destroy(t, ecsClusterTerratestOptions)
	ecsClusterTerratestOptions.Vars["docker_image_command"] = []string{"sleep", "10"}
	terraform.InitAndApply(t, ecsClusterTerratestOptions)
	ecsClusterArn := getRequiredTerraformOutputVal(t, ecsClusterTerratestOptions, "ecs_cluster_arn")

	daemonServiceTerratestOptions := createDaemonServiceTerratestOptions(t, uniqueId, amiId, randomRegion, daemonServiceTerraformModulePath, ecsClusterArn)
	defer terraform.Destroy(t, daemonServiceTerratestOptions)

	daemonServiceTerratestOptions.Vars["enable_ecs_deployment_check"] = "0"
	daemonServiceTerratestOptions.Vars["container_command"] = []string{"false"}
	terraform.InitAndApply(t, daemonServiceTerratestOptions)

	daemonServiceTerratestOptions.Vars["enable_ecs_deployment_check"] = "1"
	_, err := terraform.ApplyE(t, daemonServiceTerratestOptions)
	assert.NotNil(t, err)

	// We use a simple command that will indefinitely run because we don't want
	// to have to check in a datadog API key.
	daemonServiceTerratestOptions.Vars["container_command"] = []string{"yes"}
	terraform.Apply(t, daemonServiceTerratestOptions)
}
