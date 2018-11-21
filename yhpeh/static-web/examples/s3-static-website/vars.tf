# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
}

variable "aws_account_id" {
  description = "The AWS account to deploy into."
}

variable "website_domain_name" {
  description = "The name of the website and the S3 bucket to create (e.g. static.foo.com)."
}

variable "create_route53_entry" {
  description = "If set to true, create a DNS A Record in Route 53 with the domain name in var.domain_name. If you're using CloudFront, you should configure the domain name in the CloudFront module and not in this module."
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create the DNS A Record specified in var.domain_name. Only used if var.create_route53_entry is true."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "force_destroy_access_logs_bucket" {
  description = "If set to true, this will force the delete of the access logs S3 bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  default = false
}

variable "index_document" {
  description = "The path to the index document in the S3 bucket (e.g. index.html)."
  default = "index.html"
}

variable "error_document" {
  description = "The path to the error document in the S3 bucket (e.g. error.html)."
  default = "error.html"
}