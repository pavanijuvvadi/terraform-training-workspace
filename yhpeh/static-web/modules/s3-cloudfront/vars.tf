# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "bucket_name" {
  description = "The name of the S3 bucket."
}

variable "s3_bucket_is_public_website" {
  description = "Set to true if your S3 bucket is configured as a website and publicly accessible. Set to false if it's a regular S3 bucket and only privately accessible to CloudFront. If it's a public website, you can use all the S3 website features (e.g. routing, error pages), but users can bypass CloudFront and talk to S3 directly. If it's a private S3 bucket, users can only reach it via CloudFront, but you don't get all the website features."
}

variable "index_document" {
  description = "The path that you want CloudFront to query on the origin server when an end user requests the root URL (e.g. index.html)."
}

variable "error_document_404" {
  description = "The path that you want CloudFront to query on the origin server when an end user gets a 404 not found response (e.g. error.html)."
}

variable "error_document_500" {
  description = "The path that you want CloudFront to query on the origin server when an end user gets a 500 internal server error response (e.g. error.html)."
}

variable "default_ttl" {
  description = "The default amount of time, in seconds, that an object is in a CloudFront cache before CloudFront forwards another request in the absence of an 'Cache-Control max-age' or 'Expires' header."
}

variable "max_ttl" {
  description = "The maximum amount of time, in seconds, that an object is in a CloudFront cache before CloudFront forwards another request to your origin to determine whether the object has been updated. Only effective in the presence of 'Cache-Control max-age', 'Cache-Control s-maxage', and 'Expires' headers."
}

variable "min_ttl" {
  description = "The minimum amount of time that you want objects to stay in CloudFront caches before CloudFront queries your origin to see whether the object has been updated."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "bucket_website_endpoint" {
  description = "The website endpoint for this S3 bucket. This value should be of the format <BUCKET_NAME>.s3-website-<AWS_REGION>.amazonaws.com. Only used if var.s3_bucket_is_public_website is true."
  default = ""
}

variable "use_cloudfront_default_certificate" {
  description = "Set to true if you want viewers to use HTTPS to request your objects and you're using the CloudFront domain name for your distribution. You must set exactly one of var.use_cloudfront_default_certificate, var.acm_certificate_arn, or var.iam_certificate_id."
  default = true
}

variable "acm_certificate_arn" {
  description = "The ARN of the AWS Certificate Manager certificate that you wish to use with this distribution. The ACM certificate must be in us-east-1. You must set exactly one of var.use_cloudfront_default_certificate, var.acm_certificate_arn, or var.iam_certificate_id."
  default = ""
}

variable "iam_certificate_id" {
  description = "The IAM certificate identifier of the custom viewer certificate for this distribution if you are using a custom domain. You must set exactly one of var.use_cloudfront_default_certificate, var.acm_certificate_arn, or var.iam_certificate_id."
  default = ""
}

variable "create_route53_entries" {
  description = "If set to true, create a DNS A Record in Route 53 with each domain name in var.domain_names."
  default = false
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create the DNS A Records specified in var.domain_names. Only used if var.create_route53_entries is true."
  default = "replace-me"
}

variable "domain_names" {
  description = "The custom domain name to use instead of the default cloudfront.net domain name (e.g. static.foo.com). Only used if var.create_route53_entries is true."
  type = "list"
  default = []
}

variable "allowed_methods" {
  description = "Controls which HTTP methods CloudFront will forward to the S3 bucket."
  type = "list"
  default = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
}

variable "cached_methods" {
  description = "CloudFront will cache the responses for these methods."
  type = "list"
  default = ["GET", "HEAD"]
}

variable "compress" {
  description = "Whether you want CloudFront to automatically compress content for web requests that include 'Accept-Encoding: gzip' in the request header."
  default = true
}

variable "viewer_protocol_policy" {
  description = "Use this element to specify the protocol that users can use to access the files in the origin specified by TargetOriginId when a request matches the path pattern in PathPattern. One of allow-all, https-only, or redirect-to-https."
  default = "allow-all"
}

variable "forward_query_string" {
  description = "Indicates whether you want CloudFront to forward query strings to the origin. If set to true, CloudFront will cache all query string parameters."
  default = true
}

variable "forward_cookies" {
  description = "Specifies whether you want CloudFront to forward cookies to the origin that is associated with this cache behavior. You can specify all, none or whitelist. If whitelist, you must define var.whitelisted_cookie_names."
  default = "none"
}

variable "whitelisted_cookie_names" {
  description = "If you have specified whitelist in var.forward_cookies, the whitelisted cookies that you want CloudFront to forward to your origin."
  type = "list"
  default = []
}

variable "forward_headers" {
  description = "The headers you want CloudFront to forward to the origin. Set to * to forward all headers."
  type = "list"
  default = []
}

variable "s3_bucket_base_path" {
  description = "If set, CloudFront will request all content from the specified folder, rather than the root of the S3 bucket."
  default = ""
}

variable "enabled" {
  description = "Whether the distribution is enabled to accept end user requests for content."
  default = true
}

variable "is_ipv6_enabled" {
  description = "Whether the IPv6 is enabled for the distribution."
  default = true
}

variable "http_version" {
  description = "The maximum HTTP version to support on the distribution. Allowed values are http1.1 and http2."
  default = "http2"
}

variable "price_class" {
  description = "The price class for this distribution. One of PriceClass_All, PriceClass_200, PriceClass_100. Higher price classes support more edge locations, but cost more. See: https://aws.amazon.com/cloudfront/pricing/#price-classes."
  default = "PriceClass_100"
}

variable "web_acl_id" {
  description = "If you're using AWS WAF to filter CloudFront requests, the Id of the AWS WAF web ACL that is associated with the distribution."
  default = ""
}

variable "access_logs_expiration_time_in_days" {
  description = "How many days to keep access logs around for before deleting them."
  default = 30
}

variable "access_log_prefix" {
  description = "The folder in the access logs bucket where logs should be written."
  default = ""
}

variable "force_destroy_access_logs_bucket" {
  description = "If set to true, this will force the delete of the access logs S3 bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  default = false
}

variable "geo_restriction_type" {
  description = "The method that you want to use to restrict distribution of your content by country: none, whitelist, or blacklist."
  default = "none"
}

variable "geo_locations_list" {
  description = "The ISO 3166-1-alpha-2 codes for which you want CloudFront either to distribute your content (if var.geo_restriction_type is whitelist) or not distribute your content (if var.geo_restriction_type is blacklist)."
  type = "list"
  default = []
}

variable "minimum_protocol_version" {
  description = "The minimum version of the SSL protocol that you want CloudFront to use for HTTPS connections. One of SSLv3 or TLSv1. Default: SSLv3. NOTE: If you are using a custom certificate (specified with acm_certificate_arn or iam_certificate_id), and have specified sni-only in ssl_support_method, TLSv1 must be specified."
  default = "TLSv1"
}

variable "ssl_support_method" {
  description = "Specifies how you want CloudFront to serve HTTPS requests. One of vip or sni-only. Required if you specify acm_certificate_arn or iam_certificate_id. NOTE: vip causes CloudFront to use a dedicated IP address and may incur extra charges."
  default = "sni-only"
}

variable "trusted_signers" {
  description = "The list of AWS account IDs that you want to allow to create signed URLs for private content."
  type = "list"
  default = []
}

variable "include_cookies_in_logs" {
  description = "Specifies whether you want CloudFront to include cookies in access logs."
  default = false
}