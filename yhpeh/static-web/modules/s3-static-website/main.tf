# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP AN S3 BUCKET TO HOST A STATIC WEBSITE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET FOR HOSTING THE WEBSITE
# Note that this bucket is only created if var.should_redirect_all_requests is false.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "website" {
  count = "${1 - var.should_redirect_all_requests}"

  bucket = "${var.website_domain_name}"
  acl    = "${var.restrict_access_to_cloudfront ? "private" : "public-read"}"
  policy = "${element(concat(data.aws_iam_policy_document.cloudfront_only_bucket_policy.*.json, data.aws_iam_policy_document.public_bucket_policy.*.json), 0)}"

  website {
    index_document = "${var.index_document}"
    error_document = "${var.error_document}"
    routing_rules = "${var.routing_rules}"
  }

  versioning {
    enabled = "${var.enable_versioning}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.access_logs.id}"
    target_prefix = "${var.access_log_prefix}"
  }

  server_side_encryption_configuration = "${var.server_side_encryption_configuration}"

  cors_rule = "${var.cors_rule}"

  force_destroy = "${var.force_destroy_website}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET FOR REDIRECTS
# Note that this bucket is only created if var.should_redirect_all_requests is true. Unfortuantely, Terraform does not
# let you simply set the redirect_all_requests_to parameter to an empty string. If you set it at all, you can't set
# index_document or error_document or any of the other properties. Therefore, we need to aws_s3_bucket resources.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "redirect" {
  count = "${var.should_redirect_all_requests}"

  bucket = "${var.website_domain_name}"
  acl    = "public-read"
  policy = "${element(concat(data.aws_iam_policy_document.cloudfront_only_bucket_policy.*.json, data.aws_iam_policy_document.public_bucket_policy.*.json), 0)}"

  website {
    redirect_all_requests_to = "${var.redirect_all_requests_to}"
  }

  versioning {
    enabled = "${var.enable_versioning}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.access_logs.id}"
    target_prefix = "${var.access_log_prefix}"
  }

  force_destroy = "${var.force_destroy_redirect}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A PUBLIC POLICY FOR THE S3 BUCKET
# This policy allows everyone to view the S3 bucket directly. This is only created if var.limit_access_to_cloudfront
# is false.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "public_bucket_policy" {
  count = "${1 - var.restrict_access_to_cloudfront}"

  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.website_domain_name}/*"]

    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDFRONT-ONLY POLICY FOR THE S3 BUCKET
# This policy allows only CloudFront to access the S3 bucket directly, so everyone else must go via the CDN. This is
# only created if var.limit_access_to_cloudfront is true.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudfront_only_bucket_policy" {
  count = "${var.restrict_access_to_cloudfront}"

  statement {
    effect = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.website_domain_name}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${var.cloudfront_origin_access_identity_iam_arn}"]
    }
  }

  statement {
    effect = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.website_domain_name}"]

    principals {
      type        = "AWS"
      identifiers = ["${var.cloudfront_origin_access_identity_iam_arn}"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SEPARATE S3 BUCKET TO STORE ACCESS LOGS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.website_domain_name}-logs"
  acl = "log-delivery-write"
  force_destroy = "${var.force_destroy_access_logs_bucket}"

  lifecycle_rule {
    id = "log"
    prefix = "${var.access_log_prefix}"
    enabled = true

    expiration {
      days = "${var.access_logs_expiration_time_in_days}"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONALLY CREATE A ROUTE 53 ENTRY FOR THE BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "website" {
  count = "${var.create_route53_entry}"

  zone_id = "${var.hosted_zone_id}"
  name = "${var.website_domain_name}"
  type = "A"

  alias {
    name = "${element(concat(aws_s3_bucket.website.*.website_domain, aws_s3_bucket.redirect.*.website_domain), 0)}"
    zone_id = "${element(concat(aws_s3_bucket.website.*.hosted_zone_id, aws_s3_bucket.redirect.*.hosted_zone_id), 0)}"
    evaluate_target_health = true
  }
}
