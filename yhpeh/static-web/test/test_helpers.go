package test

import (
	"github.com/gruntwork-io/terratest"
	"testing"
	"log"
	"fmt"
	"net/http"
	"github.com/gruntwork-io/terratest/util"
	"time"
	"strings"
	"io/ioutil"
)

// A Route 53 hosted zone that's available in the Phoenix DevOps AWS account
const DOMAIN_NAME_FOR_TEST = "gruntwork.in"
const HOSTED_ZONE_ID_FOR_TEST = "Z2AJ7S3R6G9UYJ"

// An ACM cert provisioned in us-east-1 in the Phoenix DevOps AWS account
const ACM_CERT_DOMAIN_NAME_FOR_TEST = "*.gruntwork.in"

func createRandomResourceCollection(t *testing.T) *terratest.RandomResourceCollection {
	resourceCollectionOptions := terratest.NewRandomResourceCollectionOptions()

	randomResourceCollection, err := terratest.CreateRandomResourceCollection(resourceCollectionOptions)
	if err != nil {
		t.Fatalf("Failed to create random resource collection: %s\n", err.Error())
	}

	return randomResourceCollection
}

func createBaseTerratestOptions(testName string, templatesPath string, randomResourceCollection *terratest.RandomResourceCollection) *terratest.TerratestOptions {
	terratestOptions := terratest.NewTerratestOptions()

	terratestOptions.UniqueId = randomResourceCollection.UniqueId
	terratestOptions.TemplatePath = templatesPath
	terratestOptions.TestName = testName

	terratestOptions.Vars = map[string]interface{} {
		"aws_region": randomResourceCollection.AwsRegion,
		"aws_account_id": randomResourceCollection.AccountId,
		"force_destroy_access_logs_bucket": 1,
	}

	return terratestOptions
}

// S3 bucket names can contain only lowercase alphanumeric characters and hyphens
func cleanupNameForS3Bucket(name string) string {
	return strings.ToLower(name)
}

func formatDomainName(baseName string, resourceCollection *terratest.RandomResourceCollection) string {
	return cleanupNameForS3Bucket(fmt.Sprintf("%s-%s.%s", baseName, resourceCollection.UniqueId, DOMAIN_NAME_FOR_TEST))
}

func terraformApply(t *testing.T, terratestOptions *terratest.TerratestOptions) {
	if _, err := terratest.Apply(terratestOptions); err != nil {
		t.Fatalf("Failed to run terraform apply: %v", err)
	}
}

func testWebsite(t *testing.T, protocol string, domainNameOutput string, path string, expectedStatusCode int, expectedBodyText string, maxRetries int, sleepBetweenRetries time.Duration, terratestOptions *terratest.TerratestOptions, logger *log.Logger) {
	domainName, err := terratest.Output(terratestOptions, domainNameOutput)
	if err != nil {
		t.Fatalf("Failed to get output %s: %v", domainNameOutput, err)
	}
	if domainName == "" {
		t.Fatalf("Output %s was empty", domainNameOutput)
	}

	url := fmt.Sprintf("%s://%s/%s", protocol, domainName, path)
	description := fmt.Sprintf("Making HTTP request to %s", url)
	logger.Printf(description)

	output, err := util.DoWithRetry(description, maxRetries, sleepBetweenRetries, logger, func() (string, error) {
		resp, err := http.Get(url)
		if err != nil {
			return "", err
		}

		defer resp.Body.Close()
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return "", err
		}

		if resp.StatusCode == expectedStatusCode {
			logger.Printf("Got expected status code %d from URL %s", expectedStatusCode, url)
			return string(body), nil
		} else {
			return "", fmt.Errorf("Expected status code %d but got %d from URL %s", expectedStatusCode, resp.StatusCode, url)
		}
	})

	if err != nil {
		t.Fatalf("Failed to call URL %s: %v", url, err)
	}

	if strings.Contains(output, expectedBodyText) {
		logger.Printf("URL %s contained expected text %s!", url, expectedBodyText)
	} else {
		t.Fatalf("URL %s did not contain expected text %s. Instead, it returned:\n%s", url, expectedBodyText, output)
	}
}
