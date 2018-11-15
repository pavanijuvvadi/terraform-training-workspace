# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A STATIC WEBSITE IN AN S3 BUCKET
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = "${var.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${var.aws_account_id}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE STATIC WEBSITE
# ---------------------------------------------------------------------------------------------------------------------

module "static_website" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/package-static-assets.git//modules/s3-static-website?ref=v1.0.8"
  source = "../../modules/s3-static-website"

  website_domain_name = "${var.website_domain_name}"
  index_document = "${var.index_document}"
  error_document = "${var.error_document}"

  create_route53_entry = "${var.create_route53_entry}"
  hosted_zone_id = "${var.hosted_zone_id}"

  # This is only set here so we can easily run automated tests on this code. You should NOT copy this setting into
  # your real applications.
  force_destroy_access_logs_bucket = "${var.force_destroy_access_logs_bucket}"
}

# ---------------------------------------------------------------------------------------------------------------------
# UPLOAD THE EXAMPLE WEBSITE INTO THE S3 BUCKET
# Normally, you would have some sort of CI process upload your static website, but to keep this example simple, we are
# using Terraform to do it.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_object" "index" {
  bucket = "${var.website_domain_name}"
  key = "${var.index_document}"
  source = "${path.module}/../example-website/index.html"
  etag = "${md5(file("${path.module}/../example-website/index.html"))}"
  content_type = "text/html"

  depends_on = ["module.static_website"]
}

resource "aws_s3_bucket_object" "error" {
  bucket = "${var.website_domain_name}"
  key = "${var.error_document}"
  source = "${path.module}/../example-website/error.html"
  etag = "${md5(file("${path.module}/../example-website/error.html"))}"
  content_type = "text/html"

  depends_on = ["module.static_website"]
}

resource "aws_s3_bucket_object" "grunty" {
  bucket = "${var.website_domain_name}"
  key = "grunty.png"
  source = "${path.module}/../example-website/grunty.png"
  etag = "${md5(file("${path.module}/../example-website/grunty.png"))}"
  content_type = "image/png"

  depends_on = ["module.static_website"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A BUCKET FOR REDIRECTS
# This bucket just redirects all requests to it to the static website bucket created above. This is useful when you
# are running a static website on www.foo.com and want to redirect all requests from foo.com to www.foo.com too.
# ---------------------------------------------------------------------------------------------------------------------

module "redirect" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/package-static-assets.git//modules/s3-static-website?ref=v1.0.8"
  source = "../../modules/s3-static-website"

  website_domain_name = "redirect-${var.website_domain_name}"
  should_redirect_all_requests = true
  redirect_all_requests_to = "${module.static_website.website_domain_name}"

  create_route53_entry = "${var.create_route53_entry}"
  hosted_zone_id = "${var.hosted_zone_id}"

  # This is only set here so we can easily run automated tests on this code. You should NOT copy this setting into
  # your real applications.
  force_destroy_access_logs_bucket = "${var.force_destroy_access_logs_bucket}"
}
