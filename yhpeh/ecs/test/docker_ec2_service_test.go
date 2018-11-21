package test

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	testName string
	testFunc func(*testing.T, string, string, string, string)
}{
	{
		"TestAlbDockerServiceWithCanaryDeploymentCheckFailByContainer",
		albDockerServiceWithCanaryDeploymentCheckFailByContainerTest,
	},
	{
		"TestAlbDockerServiceWithCanaryDeployment",
		albDockerServiceWithCanaryDeploymentTest,
	},
	{
		"TestDockerServiceWithAlbContainerRedeploy",
		dockerServiceWithAlbContainerRedeployTest,
	},
	{
		"TestElbDockerServiceWithCanaryDeploymentCheckFailByContainer",
		elbDockerServiceWithCanaryDeploymentCheckFailByContainerTest,
	},
	{
		"TestElbDockerServiceWithCanaryDeployment",
		elbDockerServiceWithCanaryDeploymentTest,
	},
	{
		"TestDockerServiceWithElbContainerRedeploy",
		dockerServiceWithElbContainerRedeployTest,
	},
	{
		"TestDeployEcsTask",
		deployEcsTaskTest,
	},
	{
		"TestDockerDaemonService",
		dockerDaemonServiceTest,
	},
	{
		"TestDockerDaemonServiceDeploymentCheckFailByContainer",
		dockerDaemonServiceDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithAlbContainerDeploymentCheckFailByContainer",
		dockerServiceWithAlbContainerDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithAlbContainerDeploymentCheckFailByContainerApp",
		dockerServiceWithAlbContainerDeploymentCheckFailByContainerAppTest,
	},
	{
		"TestDockerServiceWithAlbContainerDeploymentCheckFailByMemory",
		dockerServiceWithAlbContainerDeploymentCheckFailByMemoryTest,
	},
	{
		"TestElbDockerServiceWithAutoScalingDeploymentCheckFailByContainer",
		elbDockerServiceWithAutoScalingDeploymentCheckFailByContainerTest,
	},
	{
		"TestAlbDockerServiceWithAutoScalingDeploymentCheckFailByContainer",
		albDockerServiceWithAutoScalingDeploymentCheckFailByContainerTest,
	},
	{
		"TestElbDockerServiceWithAutoScaling",
		elbDockerServiceWithAutoScalingTest,
	},
	{
		"TestAlbDockerServiceWithAutoScaling",
		albDockerServiceWithAutoScalingTest,
	},
	{
		"TestDockerServiceWithElbContainerDeploymentCheckFailByContainer",
		dockerServiceWithElbContainerDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithoutElbDeploymentCheckFailByContainer",
		dockerServiceWithoutElbDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithoutElb",
		dockerServiceWithoutElbTest,
	},
	{
		"TestAlbDockerServiceWithCanaryDeploymentCheckSkip",
		albDockerServiceWithCanaryDeploymentCheckSkip,
	},
	{
		"TestElbDockerServiceWithCanaryDeploymentCheckSkip",
		elbDockerServiceWithCanaryDeploymentCheckSkip,
	},
	{
		"TestServiceDiscovery",
		serviceDiscoveryTests,
	},
}

func TestDockerEC2Service(t *testing.T) {
	t.Parallel()

	workingDir := "./"
	test_structure.RunTestStage(t, "build_ami", func() {
		awsRegion := getRandomRegion(t)
		amiId := buildAmi(t, awsRegion)
		test_structure.SaveString(t, workingDir, "awsRegion", awsRegion)
		test_structure.SaveString(t, workingDir, "amiId", amiId)
	})
	defer test_structure.RunTestStage(t, "delete_ami", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "awsRegion")
		amiId := test_structure.LoadString(t, workingDir, "amiId")
		aws.DeleteAmi(t, awsRegion, amiId)
	})

	// create a temp dir for provider plugin cache
	cacheDir, err := ioutil.TempDir("", "provider_plugin_cache")
	if !assert.Nil(t, err) {
		os.Setenv("TF_PLUGIN_CACHE_DIR", cacheDir)
	}

	// Spawn a grouped test that is not marked as parallel, so that we will wait for all the parallel subtests to
	// finish, so that we can clean up after all the tests are done.
	t.Run("group", func(t *testing.T) {
		for _, testCase := range testCases {
			testCase := testCase
			t.Run(testCase.testName, func(t *testing.T) {
				t.Parallel()
				uniqueId := random.UniqueId()
				testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
				awsRegion := test_structure.LoadString(t, workingDir, "awsRegion")
				amiId := test_structure.LoadString(t, workingDir, "amiId")
				testCase.testFunc(t, uniqueId, awsRegion, amiId, testFolder)
			})
		}
	})
}

// Service discovery tests require creating a VPC, but we will quickly hit the limit if we create a VPC per test, so
// instead we share one VPC created before hand.
var serviceDiscoveryTestCases = []struct {
	testName string
	testFunc func(
		*testing.T,
		string,
		string,
		string,
		string,
		string,
		[]string,
		[]string,
		string,
		string,
	)
}{
	{
		"TestDockerServiceWithPrivateDiscoveryDeploymentCheckFailByContainer",
		dockerServiceWithPrivateDiscoveryDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithPublicDiscoveryDeploymentCheckFailByContainer",
		dockerServiceWithPublicDiscoveryDeploymentCheckFailByContainerTest,
	},
	{
		"TestDockerServiceWithPrivateDiscovery",
		dockerServiceWithPrivateDiscoveryTest,
	},
	{
		"TestDockerServiceWithPublicDiscovery",
		dockerServiceWithPublicDiscoveryTest,
	},
}

func serviceDiscoveryTests(
	t *testing.T,
	uniqueId string,
	randomRegion string,
	amiId string,
	testFolder string,
) {
	terraformModulePath := filepath.Join(testFolder, "example-vpc")
	terratestOptions := createExampleVpcTerratestOptions(t, uniqueId, randomRegion, terraformModulePath)
	defer terraform.Destroy(t, terratestOptions)
	terraform.InitAndApply(t, terratestOptions)

	vpcId := getRequiredTerraformOutputVal(t, terratestOptions, "vpc_id")
	privateSubnetIds := terraform.OutputList(t, terratestOptions, "private_subnet_ids")
	publicSubnetIds := terraform.OutputList(t, terratestOptions, "public_subnet_ids")
	publicNamespaceId := getRequiredTerraformOutputVal(t, terratestOptions, "public_namespace_id")
	publicNamespaceHostedZone := getRequiredTerraformOutputVal(t, terratestOptions, "public_namespace_hosted_zone")

	t.Run("subgroup", func(t *testing.T) {
		for _, testCase := range serviceDiscoveryTestCases {
			testCase := testCase
			t.Run(testCase.testName, func(t *testing.T) {
				t.Parallel()
				uniqueId := random.UniqueId()
				testFolder := test_structure.CopyTerraformFolderToTemp(t, "..", "examples")
				testCase.testFunc(
					t,
					uniqueId,
					randomRegion,
					amiId,
					testFolder,
					vpcId,
					privateSubnetIds,
					publicSubnetIds,
					publicNamespaceId,
					publicNamespaceHostedZone,
				)
			})
		}
	})
}
