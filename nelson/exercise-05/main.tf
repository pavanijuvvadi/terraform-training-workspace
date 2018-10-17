
provider "aws" {
  region = "ap-southeast-1" # You might want to use ap-southeast-1
}


module "frontend_app" {
  source = "./modules"

  name = "nelson-frontend"
  num_servers = 2
  enable_route53_health_check = true
}

module "backend_app" {
  source = "./modules"

  name = "nelson-backend"
  num_servers = 3
  enable_route53_health_check = false
}
