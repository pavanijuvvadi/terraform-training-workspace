# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "website_domain_name" {
  description = "The name of the website and the S3 bucket to create (e.g. static.foo.com)."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "cors_rule" {
  description = "A configuration for CORS on the S3 bucket. Default value comes from AWS. Can override for custom CORS by passing the object structure define in the documentation https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#using-cors."
  type = "list"
  default = []
}

variable "index_document" {
  description = "The path to the index document in the S3 bucket (e.g. index.html)."
  default = "index.html"
}

variable "error_document" {
  description = "The path to the error document in the S3 bucket (e.g. error.html)."
  default = "error.html"
}

variable "restrict_access_to_cloudfront" {
  description = "If set to true, the S3 bucket will only be accessible via CloudFront, and not directly. You must specify var.cloudfront_origin_access_identity_iam_arn if you set this variable to true."
  default = false
}

variable "cloudfront_origin_access_identity_iam_arn" {
  description = "The IAM ARN of the CloudFront origin access identity. Only used if var.use_with_cloudfront is true."
  default = "replace-me"
}

variable "enable_versioning" {
  description = "Set to true to enable versioning. This means the bucket will retain all old versions of all files. This is useful for backup purposes (e.g. you can rollback to an older version), but it may mean your bucket uses more storage."
  default = true
}

variable "routing_rules" {
  description = "A json array containing routing rules describing redirect behavior and when redirects are applied. For routing rule syntax, see: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-websiteconfiguration-routingrules.html."
  default = ""
}

variable "create_route53_entry" {
  description = "If set to true, create a DNS A Record in Route 53 with the domain name in var.website_domain_name. If you're using CloudFront, you should configure the domain name in the CloudFront module and not in this module."
  default = false
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create the DNS A Record specified in var.website_domain_name. Only used if var.create_route53_entry is true."
  default = "replace-me"
}

variable "should_redirect_all_requests" {
  description = "If set to true, this implies that this S3 bucket is only for redirecting all requests to another domain name specified in var.redirect_all_requests_to. This is useful to setup a bucket to redirect, for example, foo.com to www.foo.com."
  default = false
}

variable "server_side_encryption_configuration" {
  description = "A configuration for server side encryption (SSE) on the S3 bucket. Defaults to AES256. The list should contain the object structure defined in the documentation https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#enable-default-server-side-encryption. To opt out of encryption set the variable to an empty list []."
  type = "list"
  default = [{
    rule = [{
      apply_server_side_encryption_by_default = [{
        sse_algorithm     = "AES256"
        kms_master_key_id = ""
      }]
    }]
  }]
}

variable "redirect_all_requests_to" {
  description = "The URL to redirect all requests to. Only used if var.should_redirect_all_requests is true."
  default = "replace-me"
}

variable "access_logs_expiration_time_in_days" {
  description = "How many days to keep access logs around for before deleting them."
  default = 30
}

variable "access_log_prefix" {
  description = "The folder in the access logs bucket where logs should be written."
  default = ""
}

variable "force_destroy_website" {
  description = "If set to true, this will force the delete of the website S3 bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  default = false
}

variable "force_destroy_redirect" {
  description = "If set to true, this will force the delete of the redirect S3 bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  default = false
}

variable "force_destroy_access_logs_bucket" {
  description = "If set to true, this will force the delete of the access logs S3 bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  default = false
}
