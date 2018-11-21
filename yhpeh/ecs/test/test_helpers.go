package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/gruntwork-io/gruntwork-cli/errors"

	terraAws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const PACKER_TEMPLATE_PATH = "../examples/example-ecs-instance-ami/build.json"

func getRandomRegion(t *testing.T) string {
	// Approve only regions where ECS, the ECS optimized Linux AMI, and ECS Service Discovery is supported
	approvedRegions := []string{"us-east-1", "us-east-2", "us-west-1", "us-west-2", "eu-west-1"}
	return terraAws.GetRandomRegion(t, approvedRegions, []string{})
}

func getRandomFargateSupportedRegion(t *testing.T) string {
	supportedFargateRegions := []string{"us-east-1", "us-east-2", "us-west-2", "eu-west-1"}
	return terraAws.GetRandomRegion(t, supportedFargateRegions, []string{})
}

func buildAmi(t *testing.T, region string) string {
	branchName, err := getCurrentBranchName(t)
	if err != nil {
		t.Fatalf("Failed to get current branch name: %s\n", err.Error())
	}

	options := &packer.Options{
		Template: PACKER_TEMPLATE_PATH,
		Vars: map[string]string{
			"aws_region":        region,
			"module_ecs_branch": branchName,
		},
	}

	amiId, err := packer.BuildAmiE(t, options)
	if err != nil {
		t.Fatalf("Failed to build AMI: %s\n", err.Error())
	}
	if amiId == "" {
		t.Fatalf("Got blank AMI ID for Packer template %s", options.Template)
	}

	return amiId
}

// Same as terraform.Output, but will halt progression if
// value is empty
func getRequiredTerraformOutputVal(t *testing.T, terratestOptions *terraform.Options, outputName string) string {
	value := terraform.Output(t, terratestOptions, outputName)
	if value == "" {
		t.Fatalf("Got empty value for required output %s", outputName)
	}
	return value
}

func getSubnetIds(subnets []terraAws.Subnet) []string {
	subnetIds := []string{}

	for _, subnet := range subnets {
		subnetIds = append(subnetIds, subnet.Id)
	}

	return subnetIds
}

// Return the name of the current branch. We need this so that when the Packer build runs gruntwork-install, it uses
// the latest code checked into the branch we're on now and not what's in a published release from before.
func getCurrentBranchName(t *testing.T) (string, error) {
	branchNameFromCircleCi := os.Getenv("CIRCLE_BRANCH")
	if branchNameFromCircleCi != "" {
		return branchNameFromCircleCi, nil
	}

	return shell.RunCommandAndGetOutputE(t, shell.Command{Command: "git", Args: []string{"rev-parse", "--symbolic-full-name", "--abbrev-ref", "HEAD"}})
}

// Run the roll-out-ecs-cluster-update.py script to roll out a change to an ECS cluster
func doEcsClusterRollout(t *testing.T, terratestOptions *terraform.Options) {
	asgName := terraform.Output(t, terratestOptions, "asg_name")
	ecsClusterName := terraform.Output(t, terratestOptions, "ecs_cluster_name")
	awsRegion := terraform.Output(t, terratestOptions, "aws_region")

	args := []string{
		"../modules/ecs-cluster/roll-out-ecs-cluster-update.py",
		"--asg-name", asgName,
		"--cluster-name", ecsClusterName,
		"--aws-region", awsRegion,
	}

	shell.RunCommand(t, shell.Command{Command: "python", Args: args})
}

func getIpForInstanceInAsg(region string, asgName string) (string, error) {
	asg, err := findAsg(region, asgName)
	if err != nil {
		return "", errors.WithStackTrace(err)
	}
	if len(asg.Instances) == 0 {
		err := fmt.Errorf("Auto Scaling Group %s has no instances", asgName)
		return "", errors.WithStackTrace(err)
	}

	return getIpForInstance(region, *asg.Instances[0].InstanceId)
}

func findAsg(region string, asgName string) (*autoscaling.Group, error) {
	svc := autoscaling.New(session.New(), aws.NewConfig().WithRegion(region))

	input := &autoscaling.DescribeAutoScalingGroupsInput{AutoScalingGroupNames: []*string{aws.String(asgName)}}
	output, err := svc.DescribeAutoScalingGroups(input)
	if err != nil {
		return nil, errors.WithStackTrace(err)
	}

	for _, group := range output.AutoScalingGroups {
		if *group.AutoScalingGroupName == asgName {
			return group, nil
		}
	}

	err = fmt.Errorf("Could not find an Auto Scaling Group named %s", asgName)
	return nil, errors.WithStackTrace(err)
}

func getIpForInstance(region string, instanceId string) (string, error) {
	svc := ec2.New(session.New(), aws.NewConfig().WithRegion(region))

	input := &ec2.DescribeInstancesInput{InstanceIds: []*string{aws.String(instanceId)}}
	output, err := svc.DescribeInstances(input)
	if err != nil {
		return "", errors.WithStackTrace(err)
	}

	for _, reservation := range output.Reservations {
		for _, instance := range reservation.Instances {
			if *instance.InstanceId == instanceId {
				if instance.PublicIpAddress == nil {
					return "", fmt.Errorf("Instance with id %s does not have public ip address", instanceId)
				}
				return *instance.PublicIpAddress, nil
			}
		}
	}

	err = fmt.Errorf("Could not find an instance with id %s", instanceId)
	return "", errors.WithStackTrace(err)
}
