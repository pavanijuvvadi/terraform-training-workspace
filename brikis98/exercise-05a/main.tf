provider "aws" {
  region = "eu-west-1" # You might want to use ap-southeast-1
}

module "frontend_app" {
  source = "../exercise-04a"

  name = "jim-test-frontend"
  num_servers = 2
}

module "backend_app" {
  source = "../exercise-04a"

  name = "jim-test-backend"
  num_servers = 3
}

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