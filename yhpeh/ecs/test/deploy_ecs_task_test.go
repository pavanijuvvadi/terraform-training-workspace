package test

import (
	"fmt"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const DefaultRunEcsTaskTimeoutInSec = 60

// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func deployEcsTaskTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "deploy-ecs-task")

	terratestOptions := createBaseDeployEcsTaskTerratestOptions(t, uniqueId, amiId, terraformModulePath, randomRegion)
	defer terraform.Destroy(t, terratestOptions)

	terraform.Init(t, terratestOptions)
	testDeployEcsTask(t, terratestOptions, []string{"sleep", "10"}, 0)
	testDeployEcsTask(t, terratestOptions, []string{"false"}, 1)
}

func testDeployEcsTask(t *testing.T, terratestOptions *terraform.Options, dockerCommand []string, expectedExitCode int) {
	logger.Logf(t, "Running the ECS Task with command %v", dockerCommand)

	terratestOptions.Vars["docker_image_command"] = dockerCommand
	terraform.Apply(t, terratestOptions)

	// The ECS Cluster can take some time to boot, and if you try to run a Task too soon, you get the error
	// "No Container Instances were found in your cluster". Therefore, we do a sleep as a simple workaround.
	logger.Log(t, "Sleeping for 60 seconds to give the ECS cluster time to boot")
	time.Sleep(60 * time.Second)

	taskFamily := getRequiredTerraformOutputVal(t, terratestOptions, "ecs_task_family")
	taskRevision := getRequiredTerraformOutputVal(t, terratestOptions, "ecs_task_revision")
	cluster := getRequiredTerraformOutputVal(t, terratestOptions, "ecs_cluster_name")
	region := getRequiredTerraformOutputVal(t, terratestOptions, "aws_region")

	cmd := shell.Command{
		Command: "../modules/ecs-deploy/bin/run-ecs-task",
		Args: []string{
			"--task", fmt.Sprintf("%s:%s", taskFamily, taskRevision),
			"--cluster", cluster,
			"--region", region,
			"--timeout", strconv.Itoa(DefaultRunEcsTaskTimeoutInSec),
		},
	}

	err := shell.RunCommandE(t, cmd)
	checkExitCode(t, dockerCommand, expectedExitCode, err)
}

func checkExitCode(t *testing.T, dockerCommand []string, expectedExitCode int, actualErr error) {
	if expectedExitCode == 0 {
		if actualErr == nil {
			logger.Logf(t, "Got expected exit code 0 when running the ECS Task with command %v", dockerCommand)
		} else {
			t.Fatalf("Expected exit code 0 when running the ECS Task with command %v, but got an error: %v", dockerCommand, actualErr)
		}
	} else {
		if actualErr == nil {
			t.Fatalf("Expected a non-zero exit code when running the ECS Task with command %v, but got error was nil from the run-ecs-task command", dockerCommand)
		} else {
			actualExitCode, err := shell.GetExitCodeForRunCommandError(actualErr)
			if err != nil {
				t.Fatalf("Failed to get exit code due to error: %v", err)
			}

			if actualExitCode == expectedExitCode {
				logger.Logf(t, "Got expected exit code %d when running the ECS Task with command %v", expectedExitCode, dockerCommand)
			} else {
				t.Fatalf("Expected exit code %d but got %d when running the ECS Task with command %v", expectedExitCode, actualExitCode, dockerCommand)
			}
		}
	}
}
