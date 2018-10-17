output "frontend_url" {
  value = "http://${module.frontend_app.elb_dns_name}"
}

output "frontend_asg_name" {
  value = "http://${module.frontend_app.asg_name}"
}

output "backend_url" {
  value = "http://${module.backend_app.elb_dns_name}"
}

output "backend_asg_name" {
  value = "http://${module.backend_app.asg_name}"
}
