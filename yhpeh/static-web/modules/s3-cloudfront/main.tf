# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A CLOUDFRONT WEB DISTRIBUTION IN FRONT OF AN S3 BUCKET
# Create a CloudFront web distribution that uses an S3 bucket as an origin server
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CLOUDFRONT DISTRIBUTION FOR A PRIVATE S3 BUCKET
# If var.s3_bucket_is_public_website is false, we create this resource, which is a CloudFront distribution that can
# access a private S3 bucket, authenticating itself via Origin Access Identity. This is a more secure option, but does
# not allow you to use website features in your S3 bucket, such as routing and custom error pages.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "private_s3_bucket" {
  count = "${1 - var.s3_bucket_is_public_website}"

  aliases = ["${var.domain_names}"]
  enabled = "${var.enabled}"
  comment = "Serve S3 bucket ${var.bucket_name} via CloudFront."

  default_root_object = "${var.index_document}"
  web_acl_id = "${var.web_acl_id}"

  is_ipv6_enabled = "${var.is_ipv6_enabled}"
  http_version = "${var.http_version}"
  price_class = "${var.price_class}"

  origin {
    # If you set the origin domain_name to <BUCKET_NAME>.s3.amazonaws.com (the REST URL), CloudFront recognizes it as
    # an S3 bucket and a) it will talk to S3 over HTTPS and b) you can keep the bucket private and only allow it to be
    # accessed via CloudFront by using Origin Access Identity.
    #
    # The downside is that the S3 website features, such as routing and error pages, will NOT work with such a URL.
    # Moreover, this ONLY seems to work correctly if the bucket is in us-east-1.
    #
    # For more info, see:
    #
    # http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html
    # http://stackoverflow.com/a/22750923/483528
    #
    domain_name = "${var.bucket_name}.s3.amazonaws.com"
    origin_id = "${var.bucket_name}"
    origin_path = "${var.s3_bucket_base_path}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  logging_config {
    include_cookies = "${var.include_cookies_in_logs}"
    bucket = "${aws_s3_bucket.access_logs.id}.s3.amazonaws.com"
    prefix = "${var.access_log_prefix}"
  }

  default_cache_behavior {
    allowed_methods = ["${var.allowed_methods}"]
    cached_methods = ["${var.cached_methods}"]
    compress = "${var.compress}"
    trusted_signers = ["${var.trusted_signers}"]

    default_ttl = "${var.default_ttl}"
    min_ttl = "${var.min_ttl}"
    max_ttl = "${var.max_ttl}"

    target_origin_id = "${var.bucket_name}"
    viewer_protocol_policy = "${var.viewer_protocol_policy}"

    forwarded_values {
      query_string = "${var.forward_query_string}"
      headers = ["${var.forward_headers}"]

      cookies {
        forward = "${var.forward_cookies}"
        whitelisted_names = ["${var.whitelisted_cookie_names}"]
      }
    }
  }

  custom_error_response {
    error_code = 404
    response_code = 404
    response_page_path = "/${var.error_document_404}"
  }

  custom_error_response {
    error_code = 500
    response_code = 500
    response_page_path = "/${var.error_document_500}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "${var.geo_restriction_type}"
      locations = ["${var.geo_locations_list}"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = "${var.use_cloudfront_default_certificate}"
    acm_certificate_arn = "${var.acm_certificate_arn}"
    iam_certificate_id = "${var.iam_certificate_id}"
    minimum_protocol_version = "${var.minimum_protocol_version}"
    ssl_support_method = "${var.ssl_support_method}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CLOUDFRONT DISTRIBUTION FOR A PRIVATE S3 BUCKET
# If var.s3_bucket_is_public_website is true, we create this resource, which is a CloudFront distribution that can
# access a public S3 bucket confired as a website. This requires that the S3 bucket is completely accessible to the
# public, so it's technically possible to bypass CloudFront. The advantage is that you can use all the S3 website
# features in your bucket, such as routing rules and custom error pages.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "public_website_s3_bucket" {
  count = "${var.s3_bucket_is_public_website}"

  aliases = ["${var.domain_names}"]
  enabled = "${var.enabled}"
  comment = "Serve S3 bucket ${var.bucket_name} via CloudFront."

  default_root_object = "${var.index_document}"
  web_acl_id = "${var.web_acl_id}"

  is_ipv6_enabled = "${var.is_ipv6_enabled}"
  http_version = "${var.http_version}"
  price_class = "${var.price_class}"

  origin {
    # If you set the origin domain_name to <BUCKET_NAME>.s3-website-<AWS_REGION>.amazonaws.com (the S3 website URL),
    # CloudFront sees it as an arbitrary, opaque endpoint. It will only be able to talk to it over HTTP (since S3
    # websites don't support HTTPS) and you will have to make your bucket completely publicly accessible (you can't use
    # Origin Access Identity with arbitrary endpoints).
    #
    # The advantage of this is that all the S3 website features, such as routing and custom error pages, will work
    # correctly. Moreover, this approach works in any AWS region.
    #
    # For more info, see:
    #
    # http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html
    # http://stackoverflow.com/a/22750923/483528
    #
    domain_name = "${var.bucket_website_endpoint}"
    origin_id = "${var.bucket_name}"
    origin_path = "${var.s3_bucket_base_path}"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  logging_config {
    include_cookies = "${var.include_cookies_in_logs}"
    bucket = "${aws_s3_bucket.access_logs.id}.s3.amazonaws.com"
    prefix = "${var.access_log_prefix}"
  }

  default_cache_behavior {
    allowed_methods = ["${var.allowed_methods}"]
    cached_methods = ["${var.cached_methods}"]
    compress = "${var.compress}"
    trusted_signers = ["${var.trusted_signers}"]

    default_ttl = "${var.default_ttl}"
    min_ttl = "${var.min_ttl}"
    max_ttl = "${var.max_ttl}"

    target_origin_id = "${var.bucket_name}"
    viewer_protocol_policy = "${var.viewer_protocol_policy}"

    forwarded_values {
      query_string = "${var.forward_query_string}"
      headers = ["${var.forward_headers}"]

      cookies {
        forward = "${var.forward_cookies}"
        whitelisted_names = ["${var.whitelisted_cookie_names}"]
      }
    }
  }

  custom_error_response {
    error_code = 404
    response_code = 404
    response_page_path = "/${var.error_document_404}"
  }

  custom_error_response {
    error_code = 500
    response_code = 500
    response_page_path = "/${var.error_document_500}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "${var.geo_restriction_type}"
      locations = ["${var.geo_locations_list}"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = "${var.use_cloudfront_default_certificate}"
    acm_certificate_arn = "${var.acm_certificate_arn}"
    iam_certificate_id = "${var.iam_certificate_id}"
    minimum_protocol_version = "${var.minimum_protocol_version}"
    ssl_support_method = "${var.ssl_support_method}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ORIGIN ACCESS IDENTITY
# CloudFront will assume this identity when it makes requests to your origin servers. You can lock down your S3 bucket
# so it's not accessible directly, but only via CloudFront, by only allowing this identity to access the S3 bucket.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "For ${var.bucket_name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET TO STORE ACCESS LOGS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.bucket_name}-cloudfront-logs"
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
# OPTIONALLY CREATE ROUTE 53 ENTRIES FOR THE BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "website" {
  count = "${var.create_route53_entries * length(var.domain_names)}"

  zone_id = "${var.hosted_zone_id}"
  name = "${element(var.domain_names, count.index)}"
  type = "A"

  alias {
    name = "${element(concat(aws_cloudfront_distribution.private_s3_bucket.*.domain_name, aws_cloudfront_distribution.public_website_s3_bucket.*.domain_name), 0)}"
    zone_id = "${element(concat(aws_cloudfront_distribution.private_s3_bucket.*.hosted_zone_id, aws_cloudfront_distribution.public_website_s3_bucket.*.hosted_zone_id), 0)}"
    evaluate_target_health = true
  }
}
