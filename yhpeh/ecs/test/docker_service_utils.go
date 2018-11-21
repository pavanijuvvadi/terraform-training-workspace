package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// The Node.js server we run in the ECS cluster will download a file from S3 and append its contents, which should be
// the text in this variable, to the end of the text it returns for each request. We use this S3 file to verify that
// IAM Roles are properly working for our ECS Tasks.
const TEST_S3_FILE_TEXT = "world!"

// Deploy the container by applying the given Terraform templates.
func doContainerDeployment(t *testing.T, terratestOptions *terraform.Options, serverText string) error {
	terratestOptions.Vars["server_text"] = serverText
	_, err := terraform.ApplyE(t, terratestOptions)
	return err
}

func mustDoContainerDeployment(t *testing.T, terratestOptions *terraform.Options, serverText string) {
	if err := doContainerDeployment(t, terratestOptions, serverText); err != nil {
		t.Fatalf("Failed to apply templates: %s\n", err.Error())
	}
}

// Load Balancer tests include an S3 file that is fetched and output along with "passedInServerText" that is passed in
// through an env var. This function formats them as we expect the container at /examples/examples=docker-image to
// render them.
func formatServerTextToMatchExampleDockerImage(passedInServerText string, s3FileText string) string {
	return passedInServerText + " " + s3FileText
}

// Given a Terraform output val that refers to a DNS Name (e.g. the ALB's endpoint), return a well-formatted URL
func getUrlFromTerraformOutputVal(t *testing.T, terratestOptions *terraform.Options, terraformOutputName string) string {
	dnsName := terraform.Output(t, terratestOptions, terraformOutputName)
	if dnsName == "" {
		t.Fatalf("Got empty URL for Terraform output %s\n", terraformOutputName)
	}

	return fmt.Sprintf("http://%s", dnsName)
}

// Test the URL exposed by our test container.
func testContainerUrl(t *testing.T, url string, serverText string, s3Text string, retries int) {
	expectedServerText := formatServerTextToMatchExampleDockerImage(serverText, s3Text)

	if err := testUrl(t, url, expectedServerText, retries); err != nil {
		t.Fatalf("Failed to test URL: %s\n", err.Error())
	}
}

// Test the given URL every 30 seconds and return an error if any of the tests fails
func testUrl(t *testing.T, url string, expectedServerText string, retries int) error {
	sleepBetweenRetries := 60 * time.Second

	return http_helper.HttpGetWithRetryE(t, url, 200, expectedServerText, retries, sleepBetweenRetries)
}

// Repeatedly hit the given URL to validate that it continually returns the expectedServerText
func testUrlAlwaysReturnsExpectedText(t *testing.T, url string, expectedServerText string) error {
	for i := 0; i < 50; i++ {
		status, body, err := http_helper.HttpGetE(t, url)
		if err != nil {
			return fmt.Errorf("Got an error trying to test URL: %v", err)
		} else if status != 200 {
			return fmt.Errorf("Got a non-200 response code from URL: %d", status)
		} else if body != expectedServerText {
			return fmt.Errorf("Expected URL to return '%s' but got '%s'", expectedServerText, body)
		} else {
			logger.Logf(t, "Got 200 OK with expected body '%s' from URL at %s", body, url)
		}
	}

	return nil
}

// Continuously check the given URL every 1 second until the stopChecking channel receives a signal to stop.
func continuouslyCheckUrl(t *testing.T, url string, stopChecking <-chan bool) {
	sleepBetweenChecks := 1 * time.Second

	go func() {
		for {
			select {
			case <-stopChecking:
				logger.Logf(t, "Got signal to stop downtime checks for URL %s.\n", url)
				return
			case <-time.After(sleepBetweenChecks):
				statusCode, body, err := http_helper.HttpGetE(t, url)
				logger.Logf(t, "Got response %d and err %v from URL at %s", statusCode, err, url)
				if err != nil {
					t.Fatalf("Failed to make HTTP request to the URL at %s: %s\n", url, err.Error())
				} else if statusCode != 200 {
					t.Fatalf("Got a non-200 response (%d) from the URL at %s, which means there was downtime! Response body: %s", statusCode, url, body)
				}
			}
		}
	}()
}

func getUrlFromEcsCluster(t *testing.T, terratestOptions *terraform.Options, region string) (string, error) {
	instancePort := getRequiredTerraformOutputVal(t, terratestOptions, OUTPUT_ECS_CLUSTER_HOST_HTTP_PORT)

	instanceIP, err := getIPFromNetworkInterfaces(terratestOptions, region)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("http://%s:%s", instanceIP, instancePort), nil
}

func getIPFromNetworkInterfaces(terratestOptions *terraform.Options, region string) (string, error) {

	networkInterface, err := retryEniUntilResult(terratestOptions, region)
	if err != nil {
		return "", err
	}

	return *networkInterface.Association.PublicIp, nil
}

func retryEniUntilResult(terratestOptions *terraform.Options, region string) (*ec2.NetworkInterface, error) {
	svc := ec2.New(session.New(), aws.NewConfig().WithRegion(region))
	groupName := aws.String(terratestOptions.Vars["service_name"].(string) + "-cluster")

	for count := 0; count < 20; count++ {
		eniDesc, err := svc.DescribeNetworkInterfaces(&ec2.DescribeNetworkInterfacesInput{
			Filters: []*ec2.Filter{
				&ec2.Filter{
					Name:   aws.String("group-name"),
					Values: []*string{groupName},
				},
			},
		})

		if err != nil {
			return nil, err
		}

		if len(eniDesc.NetworkInterfaces) > 0 {
			fmt.Println("Found ENI result, checking if there's an association")
			if eniDesc.NetworkInterfaces[0].Association != nil {
				fmt.Println("There's an Association, let's return the interface")
				return eniDesc.NetworkInterfaces[0], nil
			}
		}

		fmt.Println("Didn't get expected result so sleeping for 5 seconds")
		time.Sleep(5 * time.Second)
	}

	return nil, fmt.Errorf("Didn't get expected result")
}
