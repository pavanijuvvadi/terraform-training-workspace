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
    Name = "${var.name}"
  }
}

variable "name" {
  description = "Used to namespace all the resources"
  default = "jim-testing-foo"
}

output "public_ip" {
  # Syntax: <TYPE>.<ID>.<ATTRIBUTE>
  value = "${aws_instance.example.public_ip}"
}

output "instance_id" {
  value = "${aws_instance.example.id}"
}