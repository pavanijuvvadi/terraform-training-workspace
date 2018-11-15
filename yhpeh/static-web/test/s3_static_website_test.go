package test

import (
	"testing"
	"github.com/gruntwork-io/terratest"
	terralog "github.com/gruntwork-io/terratest/log"
	"time"
)

func TestS3StaticWebsiteExample(t *testing.T) {
	t.Parallel()

	testName := "TestS3StaticWebsiteExample"
	logger := terralog.NewLogger(testName)

	resourceCollection := createRandomResourceCollection(t)
	terratestOptions := createBaseTerratestOptions(testName, "../examples/s3-static-website", resourceCollection)
	defer terratest.Destroy(terratestOptions, resourceCollection)

	terratestOptions.Vars["website_domain_name"] = formatDomainName("s3-website-example", resourceCollection)
	terratestOptions.Vars["create_route53_entry"] = 1
	terratestOptions.Vars["hosted_zone_id"] = HOSTED_ZONE_ID_FOR_TEST
	terratestOptions.Vars["acm_certificate_domain_name"] = ACM_CERT_DOMAIN_NAME_FOR_TEST

	terraformApply(t, terratestOptions)

	maxRetries := 10
	sleepBetweenRetries := 10 * time.Second

	testWebsite(t, "http", "website_domain_name", "", 200, "Hello, World!", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "http", "website_domain_name", "not-a-valid-path", 404, "Uh oh", maxRetries, sleepBetweenRetries, terratestOptions, logger)
	testWebsite(t, "http", "redirect_domain_name", "", 200, "Hello, World!", maxRetries, sleepBetweenRetries, terratestOptions, logger)
}