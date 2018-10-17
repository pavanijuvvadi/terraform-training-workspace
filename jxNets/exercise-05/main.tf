provider "aws" {
    region = "ap-southeast-1"
}

module "frontend_app" {
  source = "../exercise-04"

  name = "jingxia-test5-frontend"
  enable_route53_health_check = true
  num_servers = 2
}

module "backend_app" {
  source = "../exercise-04"

  name = "jingxia-test5-backend"
  enable_route53_health_check = false
  num_servers = 3
}