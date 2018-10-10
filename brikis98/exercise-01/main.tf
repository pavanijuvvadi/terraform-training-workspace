# Look for a plugin called "Terraform" or "HCL" in your text editor / IDE to get syntax highlighting

provider "aws" {
  region = "eu-west-1" # You might want to use ap-southeast-1
}

resource "aws_instance" "example" {
  ami = "${data.aws_ami.ubuntu.id}"

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

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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

output "default_vpc_id" {
  value = "${data.aws_vpc.default.id}"
}