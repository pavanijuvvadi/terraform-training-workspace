package test

import (
	"fmt"
	"path/filepath"
	"regexp"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

const OUTPUT_SSH_HOST_INSTANCE_ID = "ssh_host_instance_id"
const OUTPUT_SERVICE_DISCOVERY_ADDRESS = "service_discovery_address"
const CONTAINER_PORT = 3000
const PRIVATE_DISCOVERY_NAMESPACE = "ecstest.local"
const PUBLIC_DISCOVERY_NAMESPACE = "gruntwork.in"
const PUBLIC_HOSTED_ZONE_ID = "Z2AJ7S3R6G9UYJ"

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy tasks of docker containers with service discovery
// 3. Reach the service through the service discovery address
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithPrivateDiscoveryTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
	vpcId string,
	privateSubnetIds []string,
	publicSubnetIds []string,
	publicNamespaceId string,
	publicNamespaceHostedZone string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-private-discovery")

	keyPair := ssh.GenerateRSAKeyPair(t, 2048)

	terratestOptions := createDiscoveryEcsServiceTerratestOptions(
		t,
		uniqueId,
		randomRegion,
		amiId,
		keyPair,
		terraformModulePath,
		false,
		vpcId,
		privateSubnetIds,
		publicSubnetIds,
		publicNamespaceId,
		publicNamespaceHostedZone,
	)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	initialDeployServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	expectedServerText := formatServerTextToMatchExampleDockerImage(initialDeployServerText, "world!")
	doContainerDeployment(t, terratestOptions, initialDeployServerText)
	err := testServiceAccessFromCluster(t, terratestOptions, randomRegion, keyPair, expectedServerText, 20)
	assert.Nil(t, err)
}

// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithPublicDiscoveryTest(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
	vpcId string,
	privateSubnetIds []string,
	publicSubnetIds []string,
	publicNamespaceId string,
	publicNamespaceHostedZone string,
) {
	terraformModulePath := filepath.Join(testFolder, "docker-service-with-public-discovery")

	keyPair := ssh.GenerateRSAKeyPair(t, 2048)

	terratestOptions := createDiscoveryEcsServiceTerratestOptions(
		t,
		uniqueId,
		randomRegion,
		amiId,
		keyPair,
		terraformModulePath,
		true,
		vpcId,
		privateSubnetIds,
		publicSubnetIds,
		publicNamespaceId,
		publicNamespaceHostedZone,
	)
	defer terraform.Destroy(t, terratestOptions)
	terraform.Init(t, terratestOptions)

	initialDeployServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	expectedServerText := formatServerTextToMatchExampleDockerImage(initialDeployServerText, "world!")
	doContainerDeployment(t, terratestOptions, initialDeployServerText)
	err := testServiceDNSAndAccess(t, terratestOptions, randomRegion, keyPair, expectedServerText, 20)
	assert.Nil(t, err)
}

// Test accessing the service from the cluster for ECS private discovery.
// Note that this assumes failing to obtain discovery addresses
// as a fatal error and will halt test progress at that
// point, instead of returning it upstream. The returned error
// only applies to failures to access the address endpoint.
func testServiceAccessFromCluster(
	t *testing.T,
	terratestOptions *terraform.Options,
	region string,
	keyPair *ssh.KeyPair,
	expectedServerText string,
	maxRetries int,
) error {
	instanceId := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_SSH_HOST_INSTANCE_ID)
	discoveryAddress := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DISCOVERY_ADDRESS)

	_, err := retry.DoWithRetryE(t, "InstanceAccess", maxRetries, 20*time.Second, func() (string, error) {
		publicInstanceIP, err := getIpForInstance(region, instanceId)
		if err != nil {
			return "", fmt.Errorf("Failed to get IP of instance in ASG: %s\n", err.Error())
		}

		publicHost := ssh.Host{
			Hostname:    publicInstanceIP,
			SshKeyPair:  keyPair,
			SshUserName: "ec2-user",
		}

		digCommand := fmt.Sprintf("dig +short %s", discoveryAddress)
		if err := testOutputCommandFromInstance(t, digCommand, publicHost, "[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}.?]*"); err != nil {
			return "", err
		}

		curlCommand := fmt.Sprintf("curl -s %s:%d", discoveryAddress, CONTAINER_PORT)
		if err := testOutputCommandFromInstance(t, curlCommand, publicHost, expectedServerText); err != nil {
			return "", err
		}

		return "", nil
	})
	return err
}

func testServiceDNSAndAccess(
	t *testing.T,
	terratestOptions *terraform.Options,
	region string,
	keyPair *ssh.KeyPair,
	expectedServerText string,
	maxRetries int,
) error {
	instanceId := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_SSH_HOST_INSTANCE_ID)
	discoveryAddress := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_SERVICE_DISCOVERY_ADDRESS)

	digCommand := shell.Command{
		Command: "dig",
		Args:    []string{"+short", "@8.8.8.8", discoveryAddress},
	}

	_, err := retry.DoWithRetryE(t, "DnsQuery", maxRetries, 30*time.Second, func() (string, error) {
		if err := testOutputCommand(t, digCommand, "[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}.?]*"); err != nil {
			return "", err
		}

		publicInstanceIP, err := getIpForInstance(region, instanceId)
		if err != nil {
			return "", fmt.Errorf("Failed to get IP of instance in ASG: %s\n", err.Error())
		}

		publicHost := ssh.Host{
			Hostname:    publicInstanceIP,
			SshKeyPair:  keyPair,
			SshUserName: "ec2-user",
		}
		curlCommand := fmt.Sprintf("curl -s %s:%d", discoveryAddress, CONTAINER_PORT)
		if err := testOutputCommandFromInstance(t, curlCommand, publicHost, expectedServerText); err != nil {
			return "", err
		}

		return "", nil
	})
	return err
}

func testOutputCommandFromInstance(t *testing.T, command string, publicHost ssh.Host, outputRegex string) error {
	logger.Logf(t, "Running command '%s' on instance %s\n", command, publicHost.Hostname)

	stdOut, err := ssh.CheckSshCommandE(t, publicHost, command)
	if err != nil {
		return err
	}

	if err := checkOutput(t, stdOut, outputRegex); err != nil {
		return err
	}
	return nil
}

func testOutputCommand(t *testing.T, command shell.Command, outputRegex string) error {
	stdOut, err := shell.RunCommandAndGetOutputE(t, command)
	if err != nil {
		return err
	}

	if err := checkOutput(t, stdOut, outputRegex); err != nil {
		return err
	}
	return nil
}

func checkOutput(t *testing.T, ouput string, outputRegex string) error {
	if ouput == "" {
		return fmt.Errorf("No output from command.\n")
	} else if match, _ := regexp.MatchString(outputRegex, ouput); !match {
		logger.Logf(t, "Actual command output: %s\n", ouput)
		return fmt.Errorf("Output of command does not match the expected regex.\n")
	}
	return nil
}
