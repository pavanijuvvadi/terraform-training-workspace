package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Use 3 mins for deployment check, which is sufficient for these examples
const EC2_FAILURE_CHECK_TIMEOUT_SECONDS = "180"

// Use 7 mins for deployment check, which is sufficient for these examples
// NOTE: Fargate takes longer to deploy
const FARGATE_FAILURE_CHECK_TIMEOUT_SECONDS = "420"

func doSkipCheckTesting(
	t *testing.T,
	terratestOptions *terraform.Options,
	uniqueId string,
	applyVarsForFailure func(*terraform.Options),
) {
	terraform.Init(t, terratestOptions)
	failedDeployServerText := fmt.Sprintf("%s skip check failed deploy", uniqueId)
	terratestOptions.Vars["enable_ecs_deployment_check"] = "0"
	applyVarsForFailure(terratestOptions)
	mustDoContainerDeployment(t, terratestOptions, failedDeployServerText)
}

func doCanarySkipCheckTesting(
	t *testing.T,
	terratestOptions *terraform.Options,
	uniqueId string,
	applyVarsForFailure func(*terraform.Options),
	getUrl func() (string, error),
) {
	terraform.Init(t, terratestOptions)
	originalServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	canaryFailedDeployServerText := fmt.Sprintf("%s skip check deploy", uniqueId)

	// Deploy main containers and verify successful deployment
	mustDoContainerDeployment(t, terratestOptions, originalServerText)
	url, err := getUrl()
	assert.Nil(t, err)
	testContainerUrl(t, url, originalServerText, TEST_S3_FILE_TEXT, 10)

	// Now deploy canary, but set it up so that it will fail
	// Skip check and verify successful deployment
	terratestOptions.Vars["enable_ecs_deployment_check"] = "0"
	terratestOptions.Vars["canary_server_text"] = canaryFailedDeployServerText
	terratestOptions.Vars["desired_number_of_canary_tasks_to_run"] = 1
	applyVarsForFailure(terratestOptions)
	terraform.Apply(t, terratestOptions)
}

// Failure testing for docker services follow the following pattern:
// - Apply a change to terraform vars that will make it succeed
// - Enable check
// - terraform apply
// - Verify success
// - Apply a change that will make it fail
// - terraform apply
// - Verify failure is detected. This will also implicitly test that null_resource is being recreated on a change.
// Thus we need 3 functions:
// - Function to cause container to fail
// - Function to cause container to succeed
// - Function to test application URL, returning error when it can't access
func doFailureTesting(
	t *testing.T,
	terratestOptions *terraform.Options,
	uniqueId string,
	applyVarsForFailure func(*terraform.Options),
	applyVarsForSuccess func(*terraform.Options),
	testUrlAccess func(string, int) error,
) {
	terraform.Init(t, terratestOptions)

	// These tests assume deployment checks are enabled, which means by the
	// time terraform apply is done we have a sense of whether or not the
	// container is deployed and ready, so we don't need to test the URL as
	// many times as the other tests. Speeds up the test cycle since there is
	// already a long wait on the check to timeout.
	urlGetRetries := 3
	successfulDeployServerText := fmt.Sprintf("%s successful deploy", uniqueId)
	expectedSuccessfulServerText := formatServerTextToMatchExampleDockerImage(successfulDeployServerText, TEST_S3_FILE_TEXT)
	failedDeployServerText := fmt.Sprintf("%s failed deploy", uniqueId)
	expectedFailedServerText := formatServerTextToMatchExampleDockerImage(failedDeployServerText, TEST_S3_FILE_TEXT)

	terratestOptions.Vars["enable_ecs_deployment_check"] = "1"
	applyVarsForSuccess(terratestOptions)
	mustDoContainerDeployment(t, terratestOptions, successfulDeployServerText)
	assert.Nil(t, testUrlAccess(expectedSuccessfulServerText, urlGetRetries))

	applyVarsForFailure(terratestOptions)
	err := doContainerDeployment(t, terratestOptions, failedDeployServerText)
	assert.NotNil(t, err, "check-ecs-service-deployment binary did not detect failure\n")
	assert.NotNil(t, testUrlAccess(expectedFailedServerText, urlGetRetries))
}

// Tests the same scenario as doFailureTesting, but against the canary server.
func doFailureTestingWithCanary(
	t *testing.T,
	terratestOptions *terraform.Options,
	uniqueId string,
	applyVarsForFailure func(*terraform.Options),
	applyVarsForSuccess func(*terraform.Options),
	getUrl func() (string, error),
) {
	terraform.Init(t, terratestOptions)
	terratestOptions.Vars["deployment_check_timeout_seconds"] = EC2_FAILURE_CHECK_TIMEOUT_SECONDS

	// Deploy main containers and verify successful deployment
	originalServerText := fmt.Sprintf("%s initial deploy", uniqueId)
	expectedOriginalServerText := formatServerTextToMatchExampleDockerImage(originalServerText, TEST_S3_FILE_TEXT)
	mustDoContainerDeployment(t, terratestOptions, originalServerText)
	url, err := getUrl()
	assert.Nil(t, err)
	testContainerUrl(t, url, originalServerText, TEST_S3_FILE_TEXT, 10)

	// Now deploy canary with check enabled and verify it succeeds
	canarySuccessfulDeployServerText := fmt.Sprintf("%s successful deploy", uniqueId)
	expectedCanarySuccessfulServerText :=
		formatServerTextToMatchExampleDockerImage(canarySuccessfulDeployServerText, TEST_S3_FILE_TEXT)
	terratestOptions.Vars["enable_ecs_deployment_check"] = "1"
	terratestOptions.Vars["canary_server_text"] = canarySuccessfulDeployServerText
	terratestOptions.Vars["desired_number_of_canary_tasks_to_run"] = 1
	applyVarsForSuccess(terratestOptions)
	terraform.Apply(t, terratestOptions)
	err = testUrlWithCanary(t, url, expectedCanarySuccessfulServerText)
	assert.Nil(t, err)

	// Now induce a failure and verify we detect the failure
	applyVarsForFailure(terratestOptions)
	canaryFailedDeployServerText := fmt.Sprintf("%s failed deploy", uniqueId)
	expectedCanaryFailedServerText :=
		formatServerTextToMatchExampleDockerImage(canaryFailedDeployServerText, TEST_S3_FILE_TEXT)
	terratestOptions.Vars["canary_server_text"] = canaryFailedDeployServerText
	_, err = terraform.ApplyE(t, terratestOptions)
	assert.NotNil(t, err, "check-ecs-service-deployment binary did not detect failure\n")

	// Verify we can't get the new canary text
	err = testUrlWithCanary(t, url, expectedCanaryFailedServerText)
	assert.NotNil(t, err)

	// ... but make sure we can get the main server text at least once
	err = testUrlWithCanary(t, url, expectedOriginalServerText)
	assert.Nil(t, err)
}

// Same as doFailureTesting, but flips the order of the success and failure deployments so that we deploy a failing
// container first.
func doSuccessAfterFailureTesting(
	t *testing.T,
	terratestOptions *terraform.Options,
	uniqueId string,
	applyVarsForFailure func(*terraform.Options),
	applyVarsForSuccess func(*terraform.Options),
	testUrlAccess func(string, int) error,
) {
	terraform.Init(t, terratestOptions)

	// These tests assume deployment checks are enabled, which means by the
	// time terraform apply is done we have a sense of whether or not the
	// container is deployed and ready, so we don't need to test the URL as
	// many times as the other tests. Speeds up the test cycle since there is
	// already a long wait on the check to timeout.
	urlGetRetries := 3
	successfulDeployServerText := fmt.Sprintf("%s successful deploy", uniqueId)
	expectedSuccessfulServerText := formatServerTextToMatchExampleDockerImage(successfulDeployServerText, TEST_S3_FILE_TEXT)
	failedDeployServerText := fmt.Sprintf("%s failed deploy", uniqueId)
	expectedFailedServerText := formatServerTextToMatchExampleDockerImage(failedDeployServerText, TEST_S3_FILE_TEXT)

	terratestOptions.Vars["enable_ecs_deployment_check"] = "1"
	applyVarsForFailure(terratestOptions)
	err := doContainerDeployment(t, terratestOptions, failedDeployServerText)
	assert.NotNil(t, err, "check-ecs-service-deployment binary did not detect failure\n")
	assert.NotNil(t, testUrlAccess(expectedFailedServerText, urlGetRetries))

	applyVarsForSuccess(terratestOptions)
	mustDoContainerDeployment(t, terratestOptions, successfulDeployServerText)
	assert.Nil(t, testUrlAccess(expectedSuccessfulServerText, urlGetRetries))
}

// The following functions are canonical ways to induce failures

// Fail by making the container exit on boot
func causeContainerToFailOnBoot(terratestOptions *terraform.Options) {
	terratestOptions.Vars["container_command"] = []string{"false"}
}

func fixContainerFailingOnBoot(terratestOptions *terraform.Options) {
	terratestOptions.Vars["container_command"] = []string{}
}

// Fail by causing the container to shut down when it receives
// a request by skipping the creation of the S3 test file
func causeContainerToFailRequests(terratestOptions *terraform.Options) {
	terratestOptions.Vars["skip_s3_test_file_creation"] = "1"
}

func fixContainerFailingRequests(terratestOptions *terraform.Options) {
	terratestOptions.Vars["skip_s3_test_file_creation"] = "0"
}

// Fail by causing the container to request more memory than
// available
func causeContainerToFailByMemory(terratestOptions *terraform.Options) {
	terratestOptions.Vars["container_memory"] = "2048"
}

func fixContainerFailingByMemory(terratestOptions *terraform.Options) {
	terratestOptions.Vars["container_memory"] = "256"
}

// Cause the canary deployment to fail by exiting on boot
func causeCanaryContainerToFailOnBoot(terratestOptions *terraform.Options) {
	terratestOptions.Vars["canary_container_command"] = []string{"false"}
}

func fixCanaryContainerFailingOnBoot(terratestOptions *terraform.Options) {
	terratestOptions.Vars["canary_container_command"] = []string{}
}
