provider "aws" {
    region = "ap-southeast-1"
}

module "npssupport_account" {
  source        = "module"

  account_alias = "npssupportuser"
}

module "cert_account" {
  source        = "module"

  account_alias = "laylee"
}