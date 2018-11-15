# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A STATIC WEBSITE IN AN S3 BUCKET AND DEPLOY CLOUDFRONT AS A CDN IN FRONT OF IT
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

  # Don't allow access to the S3 bucket directly. Only allow CloudFront to access it.
  restrict_access_to_cloudfront = true
  cloudfront_origin_access_identity_iam_arn = "${module.cloudfront.cloudfront_origin_access_identity_iam_arn}"

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
# CREATE THE CLOUDFRONT WEB DISTRIBUTION
# ---------------------------------------------------------------------------------------------------------------------

module "cloudfront" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/package-static-assets.git//modules/s3-cloudfront?ref=v1.0.8"
  source = "../../modules/s3-cloudfront"

  bucket_name = "${var.website_domain_name}"
  s3_bucket_is_public_website = false

  index_document = "${var.index_document}"
  error_document_404 = "${var.error_document}"
  error_document_500 = "${var.error_document}"

  min_ttl = 0
  max_ttl = 60
  default_ttl = 30

  create_route53_entries = "${var.create_route53_entry}"
  domain_names = ["${var.website_domain_name}"]
  hosted_zone_id = "${var.hosted_zone_id}"

  # If var.create_route53_entry is false, the aws_acm_certificate data source won't be created. Ideally, we'd just use
  # a conditional to only use that data source if var.create_route53_entry is true, but Terraform's conditionals are
  # not short-circuiting, so both branches would be evaluated. Therefore, we use this silly trick with "join" to get
  # back an empty string if the data source was not created.
  acm_certificate_arn = "${join(",", data.aws_acm_certificate.cert.*.arn)}"
  use_cloudfront_default_certificate = false

  # This is only set here so we can easily run automated tests on this code. You should NOT copy this setting into
  # your real applications.
  force_destroy_access_logs_bucket = "${var.force_destroy_access_logs_bucket}"
}

# ---------------------------------------------------------------------------------------------------------------------
# FIND THE ACM CERTIFICATE
# If var.create_route53_entry is true, we need a custom TLS cert for our custom domain name. Here, we look for a
# cert issued by Amazon's Certificate Manager (ACM) for the domain name var.acm_certificate_domain_name.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_acm_certificate" "cert" {
  count = "${var.create_route53_entry}"
  domain   = "${var.acm_certificate_domain_name}"
  statuses = ["ISSUED"]
}
