package test

import (
	"testing"
	terralog "github.com/gruntwork-io/terratest/log"
	"github.com/gruntwork-io/terratest"
	"time"
)

func TestCloudFrontS3PrivateExample(t *testing.T) {
	t.Parallel()

	testName := "TestCloudFrontS3PrivateExample"
	logger := terralog.NewLogger(testName)

	resourceCollection := createRandomResourceCollection(t)
	terratestOptions := createBaseTerratestOptions(testName, "../examples/cloudfront-s3-private", resourceCollection)

	// Yes, we intentionally call destroy twice here. The reason is that it can take a VERY long time to
	// undeploy a CloudFront distribution (nearly an hour) but Terraform will time out after 40 minutes. To
	// ensure everything gets cleaned up, we call destroy again with the assumption that the destroy will actually
	// complete within the second 40 minute window. For more info, see:
	// https://github.com/hashicorp/terraform/issues/13309
	defer terratest.Destroy(terratestOptions, resourceCollection)
	defer terratest.Destroy(terratestOptions, resourceCollection)

	// NOTE: for some reason, CloudFront with a private S3 bucket seem to only work in us-east-1. In all other
	// regions, you get a 403: Access Denied error. It's not clear why, so we need to investigate further. In the
	// meantime, we hardcode the test to use us-east-1.
	terratestOptions.Vars["aws_region"] = "us-east-1"

	terratestOptions.Vars["website_domain_name"] = formatDomainName("cloudfront-example", resourceCollection)
	terratestOptions.Vars["create_route53_entry"] = 1
	terratestOptions.Vars["hosted_zone_id"] = HOSTED_ZONE_ID_FOR_TEST
	terratestOptions.Vars["acm_certificate_domain_name"] = ACM_CERT_DOMAIN_NAME_FOR_TEST

	terraformApply(t, terratestOptions)

	// It can take as long as 45 minutes for the distribution to fully deploy, so we may need to keep retrying the
	// first request for a LONG time. 270 * 10 seconds = 30 minutes. After that, we can retry far less.
	initialMaxRetries := 270
	maxRetries := 10
	sleepBetweenRetries := 10 * time.Second

	testWebsite(t, "http", "cloudfront_domain_names", "", 200, "Hello, World!", initialMaxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "https", "cloudfront_domain_names", "", 200, "Hello, World!", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "http", "cloudfront_domain_names", "not-a-valid-path", 404, "Uh oh", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "https", "cloudfront_domain_names", "not-a-valid-path", 404, "Uh oh", maxRetries, sleepBetweenRetries, terratestOptions, logger)
}

func TestCloudFrontS3PublicExample(t *testing.T) {
	t.Parallel()

	testName := "TestCloudFrontS3PublicExample"
	logger := terralog.NewLogger(testName)

	resourceCollection := createRandomResourceCollection(t)
	terratestOptions := createBaseTerratestOptions(testName, "../examples/cloudfront-s3-public", resourceCollection)

	// Yes, we intentionally call destroy twice here. The reason is that it can take a VERY long time to
	// undeploy a CloudFront distribution (nearly an hour) but Terraform will time out after 40 minutes. To
	// ensure everything gets cleaned up, we call destroy again with the assumption that the destroy will actually
	// complete within the second 40 minute window. For more info, see:
	// https://github.com/hashicorp/terraform/issues/13309
	defer terratest.Destroy(terratestOptions, resourceCollection)
	defer terratest.Destroy(terratestOptions, resourceCollection)

	terratestOptions.Vars["website_domain_name"] = formatDomainName("cloudfront-example", resourceCollection)
	terratestOptions.Vars["create_route53_entry"] = 1
	terratestOptions.Vars["hosted_zone_id"] = HOSTED_ZONE_ID_FOR_TEST
	terratestOptions.Vars["acm_certificate_domain_name"] = ACM_CERT_DOMAIN_NAME_FOR_TEST

	terraformApply(t, terratestOptions)

	// It can take as long as 45 minutes for the distribution to fully deploy, so we may need to keep retrying the
	// first request for a LONG time. 270 * 10 seconds = 30 minutes. After that, we can retry far less.
	initialMaxRetries := 270
	maxRetries := 10
	sleepBetweenRetries := 10 * time.Second

	testWebsite(t, "http", "cloudfront_domain_names", "", 200, "Hello, World!", initialMaxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "https", "cloudfront_domain_names", "", 200, "Hello, World!", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "http", "cloudfront_domain_names", "not-a-valid-path", 404, "Uh oh", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "https", "cloudfront_domain_names", "not-a-valid-path", 404, "Uh oh", maxRetries, sleepBetweenRetries, terratestOptions, logger)
}