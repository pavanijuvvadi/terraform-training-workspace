provider "aws" {
  region = "ap-southeast-1"
}

module "frontend_app" {
  source = "../exercise-04a"

  name = "lee-testing-frontend"
  num_servers = 2
}

module "backend_app" {
  source = "../exercise-04a"

  name = "lee-testing-backend"
  num_servers = 3
}