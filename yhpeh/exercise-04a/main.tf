provider "aws" {
  region = "ap-southeast-1" # You might want to use ap-southeast-1
}

resource "aws_autoscaling_group" "web_servers" {
  name_prefix = "${var.name}"

  launch_configuration = "${aws_launch_configuration.web_servers.name}"
  max_size = 3
  min_size = 3

  vpc_zone_identifier = ["${data.aws_subnet_ids.default.ids}"]

  tag {
    key = "Name"
    value = "${var.name}"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "web_servers" {
  name_prefix = "${var.name}"
  image_id = "${data.aws_ami.ubuntu.id}"
  instance_type = "t3.micro"
  security_groups = ["${aws_security_group.web_server.id}"]

  user_data = <<EOF
#!/bin/bash
echo "Hello yewhock, World from $(hostname)" > index.html
nohup busybox httpd -f -p ${var.instance_http_port} &
EOF

  lifecycle {
    create_before_destroy = true
  }
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

resource "aws_security_group" "web_server" {
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

  # This is here because the aws_launch_configuration depends on this resource and aws_launch_configuration sets
  # create_before_destroy to true
  lifecycle {
    create_before_destroy = true
  }
}

variable "instance_http_port" {
  description = "The port the EC2 Instance will listen on for HTTP requests"
  default = 8080
}

variable "name" {
  description = "Used to namespace all the resources"
  default = "yewhock-test"
}
