provider "aws" {
    region = "ap-southeast-1"
}

module "npssupport_account" {
  source = "../module"

  name   = "npssupportuser"
}

module "cert_account" {
  source = "../module"

  name   = "LayLee@nets.com.sg"
}