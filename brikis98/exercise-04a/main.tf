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

  user_data = <<EOF
#!/bin/bash
echo "Hello, World from ${var.name} running at $(hostname)!!!" > index.html
nohup busybox httpd -f -p ${var.instance_http_port} &
EOF

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
    Name = "${var.name}"
  }

  # This is here because the autoscaling group sets it
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
