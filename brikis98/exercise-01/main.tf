# Look for a plugin called "Terraform" or "HCL" in your text editor / IDE to get syntax highlighting

provider "aws" {
  region = "eu-west-1" # You might want to use ap-southeast-1
}

resource "aws_instance" "example" {
  # This is Ubuntu 18.04
  # You will have a different ID in ap-southeast-1
  ami = "ami-00035f41c82244dab"

  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.example.id}"]

  user_data = <<EOF
#!/bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p ${var.instance_http_port} &
EOF

  tags {
    # You'll want to change this to your own name
    Name = "${var.name}"
  }
}

resource "aws_security_group" "example" {
  name = "${var.name}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.instance_http_port}"
    to_port = "${var.instance_http_port}"
    protocol = "tcp"
    # Don't do this in production. Limit IPs in prod to trusted servers.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "name" {
  description = "Used to namespace all the resources"
  default = "jim-testing-foo"
}

variable "instance_http_port" {
  description = "The port the EC2 Instance will listen on for HTTP requests"
  default = 8080
}

output "public_ip" {
  # Syntax: <TYPE>.<ID>.<ATTRIBUTE>
  value = "${aws_instance.example.public_ip}"
}

output "instance_id" {
  value = "${aws_instance.example.id}"
}