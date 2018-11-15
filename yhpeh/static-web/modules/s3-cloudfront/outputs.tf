output "cloudfront_domain_names" {
  value = "${split(",", var.create_route53_entries ? join(",", aws_route53_record.website.*.fqdn) : element(concat(aws_cloudfront_distribution.private_s3_bucket.*.domain_name, aws_cloudfront_distribution.public_website_s3_bucket.*.domain_name), 0))}"
}

output "cloudfront_id" {
  value = "${element(concat(aws_cloudfront_distribution.private_s3_bucket.*.id, aws_cloudfront_distribution.public_website_s3_bucket.*.id), 0)}"
}

output "cloudfront_origin_access_identity_iam_arn" {
  value = "${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
}

output "cloudfront_origin_access_identity_s3_canonical_user_id " {
  value = "${aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id }"
}

output "access_logs_bucket_arn" {
  value = "${aws_s3_bucket.access_logs.arn}"
}