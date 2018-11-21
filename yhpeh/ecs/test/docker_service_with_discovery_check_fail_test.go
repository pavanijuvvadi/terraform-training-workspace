package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test that we can:
//
// 1. Create an ECS cluster
// 2. Deploy a Docker container that will fail on it, with
//    deployment checks off
// 3. Verify the deployment checks do not run and apply completes
// 4. Apply with deployment checks on
// 5. Verify deployment check detects the failure
// 6. Verify service is down
// 7. Deploy a fixed docker container
// 8. Verify the ECS deployment check passes
// 9. Verify service is restored
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithPrivateDiscoveryDeploymentCheckFailByContainerTest(
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

	// Use 5 mins for deployment check, which is sufficient for these examples
	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	// We use the SuccessAfterFailure testing version here because the failure won't be detected by the DNS querying in
	// the standard flow.
	doSuccessAfterFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
		fixContainerFailingOnBoot,
		func(expectedServerText string, urlGetRetries int) error {
			return testServiceAccessFromCluster(t, terratestOptions, randomRegion, keyPair, expectedServerText, urlGetRetries)
		},
	)
	doSkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
	)
}

// Same as above, except test with public service discovery
// NOTE: This test is run as part of TestDockerEC2Service to
//       avoid recreating the same AMI over and over again.
func dockerServiceWithPublicDiscoveryDeploymentCheckFailByContainerTest(
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

	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS
	// We use the SuccessAfterFailure testing version here because the failure won't be detected by the DNS querying in
	// the standard flow.
	doSuccessAfterFailureTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
		fixContainerFailingOnBoot,
		func(expectedServerText string, urlGetRetries int) error {
			return testServiceDNSAndAccess(t, terratestOptions, randomRegion, keyPair, expectedServerText, 10)
		},
	)
	doSkipCheckTesting(
		t,
		terratestOptions,
		uniqueId,
		causeContainerToFailOnBoot,
	)
}
