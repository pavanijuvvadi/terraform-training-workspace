package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func createExampleVpcTerratestOptions(
	t *testing.T,
	uniqueId string,
	region string,
	templatePath string,
) *terraform.Options {
	vpcName := fmt.Sprintf("ecs-vpc-%s", uniqueId)

	terraformVars := map[string]interface{}{
		"aws_region":               region,
		"vpc_name":                 vpcName,
		"discovery_namespace_name": PUBLIC_DISCOVERY_NAMESPACE,
	}

	terratestOptions := terraform.Options{
		TerraformDir: templatePath,
		Vars:         terraformVars,
	}
	return &terratestOptions

}

func createElbEcsServiceTerratestOptions(
	t *testing.T,
	uniqueId string,
	region string,
	amiId string,
	templatePath string,
) *terraform.Options {
	awsAccountId := aws.GetAccountId(t)
	clusterName := fmt.Sprintf("Test-cluster%s", uniqueId)
	serviceName := fmt.Sprintf("test-service-%s", uniqueId)

	vpc := aws.GetDefaultVpc(t, region)

	terraformVars := map[string]interface{}{
		"aws_region":                    region,
		"aws_account_id":                awsAccountId,
		"cluster_name":                  clusterName,
		"cluster_instance_ami":          amiId,
		"cluster_instance_keypair_name": "",
		"vpc_id":                        vpc.Id,
		"ecs_cluster_vpc_subnet_ids":    getSubnetIds(vpc.Subnets),
		"elb_subnet_ids":                getSubnetIds(vpc.Subnets),
		"service_name":                  serviceName,
		"environment_name":              uniqueId,
		"enable_ecs_deployment_check":   "1",
	}

	retryableTerraformErrors := map[string]string{
		"Unable to assume role and validate the listeners configured on your load balancer":                       "An eventual consistency bug in Terraform related to IAM role propagation and ECS. More details here: https://github.com/hashicorp/terraform/issues/4375.",
		"Error creating launch configuration: ValidationError: You are not authorized to perform this operation.": "An mysterious, intermittent error that has been happening with launch configurations recently. More details here: https://github.com/hashicorp/terraform/issues/7198",
		"does not have attribute 'id' for variable 'aws_security_group.":                                          "An mysterious, intermittent error that has been happening with launch configurations recently. More details here: https://github.com/hashicorp/terraform/issues/2583",
	}

	terratestOptions := terraform.Options{
		TerraformDir:             templatePath,
		Vars:                     terraformVars,
		RetryableTerraformErrors: retryableTerraformErrors,
	}
	return &terratestOptions
}

func createBaseDeployEcsTaskTerratestOptions(
	t *testing.T,
	uniqueId string,
	amiId string,
	templatePath string,
	randomRegion string,
) *terraform.Options {
	clusterName := fmt.Sprintf("test-cluster%s", uniqueId)

	terraformVars := map[string]interface{}{
		"aws_region":                        randomRegion,
		"ecs_cluster_name":                  clusterName,
		"ecs_cluster_instance_ami":          amiId,
		"docker_image":                      "alpine",
		"docker_image_version":              "3.6",
		"ecs_cluster_instance_keypair_name": "",
	}

	terratestOptions := terraform.Options{
		TerraformDir: templatePath,
		Vars:         terraformVars,
	}
	return &terratestOptions
}

func createDaemonServiceTerratestOptions(
	t *testing.T,
	uniqueId string,
	amiId string,
	randomRegion string,
	templatePath string,
	ecsClusterArn string,
) *terraform.Options {
	awsAccountId := aws.GetAccountId(t)
	serviceName := fmt.Sprintf("test-daemon-service%s", uniqueId)
	terraformVars := map[string]interface{}{
		"aws_account_id":   awsAccountId,
		"aws_region":       randomRegion,
		"environment_name": uniqueId,
		"cpu":              "512",
		"memory":           "512",
		"api_key":          "",
		"ecs_cluster_arn":  ecsClusterArn,
		"service_name":     serviceName,
	}
	terratestOptions := terraform.Options{
		TerraformDir: templatePath,
		Vars:         terraformVars,
	}
	return &terratestOptions
}

func createAlbEcsServiceTerratestOptions(
	t *testing.T,
	uniqueId string,
	region string,
	amiId string,
	templatePath string,
) *terraform.Options {
	awsAccountId := aws.GetAccountId(t)
	clusterName := fmt.Sprintf("%s-cluster", uniqueId)
	serviceName := fmt.Sprintf("%s-service", uniqueId)

	vpc := aws.GetDefaultVpc(t, region)

	terraformVars := map[string]interface{}{
		"aws_region":                        region,
		"aws_account_id":                    awsAccountId,
		"ecs_cluster_name":                  clusterName,
		"ecs_cluster_instance_ami":          amiId,
		"ecs_cluster_instance_keypair_name": "",
		"ecs_cluster_vpc_subnet_ids":        getSubnetIds(vpc.Subnets),
		"vpc_id":                            vpc.Id,
		"vpc_cidr_block":                    "0.0.0.0/0",
		"service_name":                      serviceName,
		"environment_name":                  "test",
		"alb_vpc_subnet_ids":                getSubnetIds(vpc.Subnets),
		"enable_ecs_deployment_check":       "1",
	}

	retryableTerraformErrors := map[string]string{
		"Unable to assume role and validate the listeners configured on your load balancer":                       "An eventual consistency bug in Terraform related to IAM role propagation and ECS. More details here: https://github.com/hashicorp/terraform/issues/4375.",
		"Error creating launch configuration: ValidationError: You are not authorized to perform this operation.": "An mysterious, intermittent error that has been happening with launch configurations recently. More details here: https://github.com/hashicorp/terraform/issues/7198",
		"does not have attribute 'id' for variable 'aws_security_group.":                                          "An mysterious, intermittent error that has been happening with launch configurations recently. More details here: https://github.com/hashicorp/terraform/issues/2583",
	}

	terratestOptions := terraform.Options{
		TerraformDir:             templatePath,
		Vars:                     terraformVars,
		RetryableTerraformErrors: retryableTerraformErrors,
	}
	return &terratestOptions
}

func createFargateTerratestOptions(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	templatePath string,
) *terraform.Options {
	serviceName := fmt.Sprintf("%s-service", uniqueId)
	terraformVars := map[string]interface{}{
		"aws_region":                  randomRegion,
		"service_name":                serviceName,
		"environment_name":            "test",
		"enable_ecs_deployment_check": "1",
		"desired_number_of_tasks":     "1",
	}

	terratestOptions := terraform.Options{
		TerraformDir: templatePath,
		Vars:         terraformVars,
	}
	return &terratestOptions
}

func createDiscoveryEcsServiceTerratestOptions(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	keyPair *ssh.KeyPair,
	templatePath string,
	publicDNS bool,
	vpcId string,
	privateSubnetIds []string,
	publicSubnetIds []string,
	publicNamespaceId string,
	publicNamespaceHostedZone string,
) *terraform.Options {
	clusterName := fmt.Sprintf("%s-ecs-cluster", uniqueId)
	serviceName := fmt.Sprintf("%s-ecs-service", uniqueId)
	awsKeyPair := aws.ImportEC2KeyPair(t, randomRegion, uniqueId, keyPair)

	var terraformVars map[string]interface{}
	if publicDNS {
		terraformVars = map[string]interface{}{
			"aws_region":                        randomRegion,
			"ecs_cluster_name":                  clusterName,
			"ecs_cluster_instance_ami":          amiId,
			"ecs_cluster_instance_keypair_name": awsKeyPair.Name,
			"vpc_id":                            vpcId,
			"private_subnet_ids":                privateSubnetIds,
			"public_subnet_ids":                 publicSubnetIds,
			"service_name":                      serviceName,
			"environment_name":                  "test",
			"discovery_namespace_name":          PUBLIC_DISCOVERY_NAMESPACE,
			"public_namespace_id":               publicNamespaceId,
			"public_namespace_hosted_zone":      publicNamespaceHostedZone,
			"container_http_port":               CONTAINER_PORT,
			"original_public_route53_zone_id":   PUBLIC_HOSTED_ZONE_ID,
		}
	} else {
		privateDiscoveryNamespace := fmt.Sprintf("%s%s", uniqueId, PRIVATE_DISCOVERY_NAMESPACE)
		terraformVars = map[string]interface{}{
			"aws_region":                        randomRegion,
			"ecs_cluster_name":                  clusterName,
			"ecs_cluster_instance_ami":          amiId,
			"ecs_cluster_instance_keypair_name": awsKeyPair.Name,
			"vpc_id":                            vpcId,
			"private_subnet_ids":                privateSubnetIds,
			"public_subnet_ids":                 publicSubnetIds,
			"service_name":                      serviceName,
			"environment_name":                  "test",
			"discovery_namespace_name":          privateDiscoveryNamespace,
			"container_http_port":               CONTAINER_PORT,
		}
	}

	terratestOptions := terraform.Options{
		TerraformDir: templatePath,
		Vars:         terraformVars,
	}
	return &terratestOptions
}
