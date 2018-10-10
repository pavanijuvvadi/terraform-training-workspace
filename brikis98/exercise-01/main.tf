# Look for a plugin called "Terraform" or "HCL" in your text editor / IDE to get syntax highlighting

provider "aws" {
  region = "eu-west-1" # You might want to use ap-southeast-1
}

resource "aws_instance" "example" {
  # This is Ubuntu 18.04
  # You will have a different ID in ap-southeast-1
  ami = "ami-00035f41c82244dab"

  instance_type = "t2.micro"

  tags {
    # You'll want to change this to your own name
    Name = "jim-testing"
  }
}