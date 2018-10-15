# Look for a plugin called "Terraform" or "HCL" in your text editor / IDE to get syntax highlighting

provider "aws" {
  region = "ap-southeast-1" # You might want to use ap-southeast-1
}

# terraform {
#   backend "s3" {
#     bucket = "nelson-terraform-test"
#     key = "nelson/exercise-01/terraform.state"
#     region = "ap-southeast-1"
#     encrypt = true
#     dynamodb_table = "nelson-terraform-test-lock"
#   }
# }

resource "aws_autoscaling_group" "web_servers" {
  name_prefix = "${aws_launch_configuration.web_servers.name}"

  launch_configuration = "${aws_launch_configuration.web_servers.name}"
  max_size = "${var.num_servers}"
  min_size = "${var.num_servers}"
  min_elb_capacity = "${var.num_servers}"

  load_balancers = ["${aws_elb.web_servers.name}"]
  health_check_type = "ELB"

  vpc_zone_identifier = ["${data.aws_subnet_ids.default.ids}"]

  tag {
    key = "Name"
    value = "${var.name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "web_servers" {
  name_prefix = "${var.name}"
  image_id = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.web_server.id}"]

#   user_data = <<EOF
# #!/bin/bash
# echo "Hello, World from EC2 instance $(hostname)" > index.html
# nohup busybox httpd -f -p ${var.instance_http_port} &
# EOF
  user_data = "${data.template_file.user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "web_servers" {
  name = "${var.name}"
  security_groups = ["${aws_security_group.elb.id}"]
  subnets = ["${data.aws_subnet_ids.default.ids}"]

  listener {
    lb_port = "${var.elb_http_port}"
    lb_protocol = "HTTP"
    instance_port = "${var.instance_http_port}"
    instance_protocol = "HTTP"
  }

  health_check {
    target = "HTTP:${var.instance_http_port}/"
    healthy_threshold = 2
    unhealthy_threshold = 5
    interval = 15
    timeout = 10
  }

  tags {
    name = "${var.name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "web_server" {
  name ="${var.name}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    # Don't do this in production. Limit by IP
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.instance_http_port}"
    to_port = "${var.instance_http_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb" {
  name = "${var.name}-elb"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.elb_http_port}"
    to_port = "${var.elb_http_port}"
    protocol = "tcp"
    # Don't do this in production. Limit IPs in prod to trusted servers.
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This is here because the autoscaling group sets it
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_health_check" "site_is_up" {
  count = "${var.enable_route53_health_check ? 1 : 0}"

  fqdn = "${aws_elb.web_servers.dns_name}"
  port = "${var.elb_http_port}"
  resource_path = "/"
  type = "HTTP"
  failure_threshold = 5
  request_interval = 30

  tags {
    Name = "${var.name}"
  }
}
