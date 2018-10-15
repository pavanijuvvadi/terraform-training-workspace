provider "aws" {
  region = "eu-west-1" # You might want to use ap-southeast-1
}

module "frontend_app" {
  source = "../exercise-04a"

  name = "jim-test-frontend"
  num_servers = 2
  enable_route53_health_check = true
}

module "backend_app" {
  source = "../exercise-04a"

  name = "jim-test-backend"
  num_servers = 3
  enable_route53_health_check = false
}