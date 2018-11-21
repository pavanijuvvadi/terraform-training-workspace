# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN EC2 CONTAINER SERVICE (ECS) CLUSTER
# These templates launch an ECS cluster you can use for running Docker containers. The cluster includes:
# - Auto Scaling Group (ASG)
# - Launch configuration
# - Security group
# - IAM roles and policies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = "~> 0.9"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER ENTITY
# Amazon's ECS Service requires that we create an entity called a "cluster". We will then register EC2 Instances with 
# that cluster.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "ecs" {
  name = "${var.cluster_name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER AUTO SCALING GROUP (ASG)
# The ECS Cluster's EC2 Instances (known in AWS as "Container Instances") exist in an Auto Scaling Group so that failed
# instances will automatically be replaced, and we can easily scale the cluster's resources.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "ecs" {
  name = "${var.cluster_name}"

  min_size             = "${var.cluster_min_size}"
  max_size             = "${var.cluster_max_size}"
  launch_configuration = "${aws_launch_configuration.ecs.name}"
  vpc_zone_identifier  = ["${var.vpc_subnet_ids}"]

  tags = ["${concat(module.default_tags.list_value, var.custom_tags_ec2_instances)}"]
}

module "default_tags" {
  source = "git::git@github.com:gruntwork-io/package-terraform-utilities.git//modules/intermediate-variable?ref=v0.0.1"

  list_value = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}"
      propagate_at_launch = true
    },
  ]
}

# Launch Configuration for the ECS Cluster's Auto Scaling Group.
resource "aws_launch_configuration" "ecs" {
  name_prefix          = "${var.cluster_name}-"
  image_id             = "${var.cluster_instance_ami}"
  instance_type        = "${var.cluster_instance_type}"
  key_name             = "${var.cluster_instance_keypair_name}"
  security_groups      = ["${aws_security_group.ecs.id}"]
  user_data            = "${var.cluster_instance_user_data}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs.name}"
  placement_tenancy    = "${var.cluster_instance_spot_price == "" ? var.tenancy : ""}"
  spot_price           = "${var.cluster_instance_spot_price}"

  root_block_device {
    volume_size = "${var.cluster_instance_root_volume_size}"
    volume_type = "${var.cluster_instance_root_volume_type}"
  }

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER INSTANCE SECURITY GROUP
# Limits which ports are allowed inbound and outbound. We export the security group id as an output so users of this
# module can add their own custom rules.
# ---------------------------------------------------------------------------------------------------------------------

# Note that we do not define ingress and egress rules inline. This is because consumers of this terraform module might
# want to add arbitrary rules to this security group. See:
# https://www.terraform.io/docs/providers/aws/r/security_group.html.
resource "aws_security_group" "ecs" {
  name        = "${var.cluster_name}"
  description = "For EC2 Instances in the ${var.cluster_name} ECS Cluster."
  vpc_id      = "${var.vpc_id}"
  tags        = "${var.custom_tags_security_group}"

  # For an explanation of why this is here, see the aws_launch_configuration.ecs
  lifecycle {
    create_before_destroy = true
  }
}

# Allow all outbound traffic from the ECS Cluster
resource "aws_security_group_rule" "allow_outbound_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.ecs.id}"
}

# Allow inbound SSH traffic from the Security Group ID specified in var.allow_ssh_from_security_group_id.
# NOTE: For now, only a single Security Group ID may be specified. If you need this module to support multiple
# Security Group IDs, please contact support@gruntwork.io.
resource "aws_security_group_rule" "allow_inbound_ssh_from_security_group" {
  # Only create this rule if var.allow_ssh is true.
  count = "${signum(var.allow_ssh)}"

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.allow_ssh_from_security_group_id}"
  security_group_id        = "${aws_security_group.ecs.id}"
}

# Allow inbound access from any ALBs that will send traffic to this ECS Cluster. We assume that the ALB will only send
# traffic to Docker containers that expose a port within the "ephemeral" port range. Per https://goo.gl/uLs9NY under
# "portMappings"/"hostPort", the ephemeral port range used by Docker will range from 32768 - 65535. It gives us pause
# to open such a wide port range, but dynamic Docker ports don't come without their costs!
resource "aws_security_group_rule" "allow_inbound_from_alb" {
  # Create one Security Group Rule for each ALB ARN specified in var.alb_arns.
  count = "${var.num_alb_security_group_ids}"

  type                     = "ingress"
  from_port                = "32768"
  to_port                  = "65535"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.alb_security_group_ids, count.index)}"
  security_group_id        = "${aws_security_group.ecs.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM ROLE AND POLICIES FOR THE CLUSTER INSTANCES
# IAM Roles allow us to grant the cluster instances access to AWS Resources. We export the IAM role id so users of this
# module can add their own custom IAM policies.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs" {
  name               = "${var.cluster_name}-instance"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_role.json}"

  # For an explanation of why this is here, see the aws_launch_configuration.ecs
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "ecs_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# To assign an IAM Role to an EC2 instance, we need to create the intermediate concept of an "IAM Instance Profile".
resource "aws_iam_instance_profile" "ecs" {
  name = "${var.cluster_name}"
  role = "${aws_iam_role.ecs.name}"

  # For an explanation of why this is here, see the aws_launch_configuration.ecs
  lifecycle {
    create_before_destroy = true
  }
}

# IAM policy we add to our EC2 Instance Role that allows an ECS Agent running on the EC2 Instance to communicate with
# an ECS cluster.
resource "aws_iam_role_policy" "ecs" {
  name   = "${var.cluster_name}-ecs-permissions"
  role   = "${aws_iam_role.ecs.id}"
  policy = "${data.aws_iam_policy_document.ecs_permissions.json}"
}

data "aws_iam_policy_document" "ecs_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
    ]

    resources = ["*"]
  }
}

# IAM policy we add to our EC2 Instance Role that allows ECS Instances to pull all containers from Amazon EC2 Container
# Registry.
resource "aws_iam_role_policy" "ecr" {
  name   = "${var.cluster_name}-docker-login-for-ecr"
  role   = "${aws_iam_role.ecs.id}"
  policy = "${data.aws_iam_policy_document.ecr_permissions.json}"
}

data "aws_iam_policy_document" "ecr_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
    ]

    resources = ["*"]
  }
}
