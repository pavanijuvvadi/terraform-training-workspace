provider "aws" {
  region = "ap-southeast-1" # You might want to use ap-southeast-1
}

module "frontend_app" {
  source = "../exercise-04b"

  name = "pyh-frontend"
  num_servers = 2
}

module "backend_app" {
  source = "../exercise-04b"

  name = "pyh-backend"
  num_servers = 3
}
