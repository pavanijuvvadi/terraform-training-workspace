output "website_domain_name" {
  value = "${var.create_route53_entry ? join(",", aws_route53_record.website.*.fqdn) : element(concat(aws_s3_bucket.website.*.website_endpoint, aws_s3_bucket.redirect.*.website_endpoint), 0)}"
}

output "website_bucket_arn" {
  value = "${element(concat(aws_s3_bucket.website.*.arn, aws_s3_bucket.redirect.*.arn), 0)}"
}

output "website_bucket_endpoint" {
  value = "${element(concat(aws_s3_bucket.website.*.website_endpoint, aws_s3_bucket.redirect.*.website_endpoint), 0)}"
}

output "access_logs_bucket_arn" {
  value = "${aws_s3_bucket.access_logs.arn}"
}