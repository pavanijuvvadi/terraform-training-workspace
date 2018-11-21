package test

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const OUTPUT_ECS_CLUSTER_ASG_NAME = "ecs_cluster_asg_name"
const OUTPUT_ECS_CLUSTER_HOST_HTTP_PORT = "host_http_port"
const OUTPUT_ECS_INSTANCE_IAM_ROLE_NAME = "ecs_instance_iam_role_name"

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container on it without an ELB
// 3. Connect to the Docker container via one of the instances in the ECS cluster
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithoutElbTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-without-elb")

	terratestOptions := createElbEcsServiceTerratestOptions(t, uniqueId, randomRegion, amiId, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)

	terraform.InitAndApply(t, terratestOptions)

	url, err := getInstanceUrlFromEcsCluster(t, terratestOptions, randomRegion)
	if err != nil {
		t.Fatalf("Failed to get URL of an instance in the ECS cluster: %s\n", err.Error())
	}

	http_helper.HttpGetWithRetry(t, url, 200, "Hello world!", 10, 60*time.Second)

	if err := validateIamRoleNameOutput(t, terratestOptions); err != nil {
		t.Fatalf("Failed to get expected value for IAM Role Name. %s", err)
	}
}

func getInstanceUrlFromEcsCluster(t *testing.T, terratestOptions *terraform.Options, region string) (string, error) {
	asgName := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_ECS_CLUSTER_ASG_NAME)
	instancePort := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_ECS_CLUSTER_HOST_HTTP_PORT)

	instanceIp, err := getIpForInstanceInAsg(region, asgName)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("http://%s:%s", instanceIp, instancePort), nil
}

func validateIamRoleNameOutput(t *testing.T, terratestOptions *terraform.Options) error {
	iamRoleName := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_ECS_INSTANCE_IAM_ROLE_NAME)

	expectedVal := fmt.Sprintf("%s-instance", terratestOptions.Vars["cluster_name"])
	if iamRoleName != expectedVal {
		return fmt.Errorf("Got '%s' for Terraform output %s, but expected '%s'", iamRoleName, OUTPUT_ECS_INSTANCE_IAM_ROLE_NAME, expectedVal)
	}

	return nil
}
