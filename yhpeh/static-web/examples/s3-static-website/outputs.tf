output "website_domain_name" {
  value = "${module.static_website.website_domain_name}"
}

output "redirect_domain_name" {
  value = "${module.redirect.website_domain_name}"
}

output "website_bucket_arn" {
  value = "${module.static_website.website_bucket_arn}"
}

output "redirect_bucket_arn" {
  value = "${module.redirect.website_bucket_arn}"
}

output "website_access_logs_bucket_arn" {
  value = "${module.static_website.access_logs_bucket_arn}"
}

output "redirect_access_logs_bucket_arn" {
  value = "${module.redirect.access_logs_bucket_arn}"
}