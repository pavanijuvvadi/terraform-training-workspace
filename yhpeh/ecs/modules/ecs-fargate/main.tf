# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A FARGATE SERVICE
# These templates create a Fargate Service which runs one or more related Docker containers in fault-tolerant way. This
# includes:
# - The Fargate Service itself
# - An optional association with an Elastic Load Balancer (ELB)
# - IAM roles and policies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_ecs_service" "fargate_without_lb" {
  count = "${1 - var.is_associated_with_lb}"

  name            = "${var.service_name}"
  cluster         = "${var.cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  launch_type     = "FARGATE"

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  network_configuration {
    subnets          = ["${var.subnet_ids}"]
    security_groups  = ["${aws_security_group.fargate.id}"]
    assign_public_ip = "${var.assign_public_ip}"
  }
}

resource "aws_ecs_service" "fargate_with_lb" {
  count = "${var.is_associated_with_lb}"

  name            = "${var.service_name}"
  cluster         = "${var.cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  launch_type     = "FARGATE"

  # Potential workaround for https://github.com/hashicorp/terraform/issues/12634#issuecomment-363849290
  depends_on = ["null_resource.lb_exists", "aws_lb_target_group.fargate_service"]

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  network_configuration {
    subnets          = ["${var.subnet_ids}"]
    security_groups  = ["${aws_security_group.fargate.id}"]
    assign_public_ip = "${var.assign_public_ip}"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.fargate_service.arn}"
    container_name   = "${var.lb_container_name}"
    container_port   = "${var.lb_container_port}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CHECK THE ECS SERVICE DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_arn" "ecs_service" {
  arn = "${local.ecs_service_arn}"
}

locals {
  ecs_service_arn = "${
    element(
      concat(
        aws_ecs_service.fargate_with_lb.*.id,
        aws_ecs_service.fargate_without_lb.*.id
      ),
      0
    )
  }"

  ecs_service_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.fargate_with_lb.*.task_definition,
        aws_ecs_service.fargate_without_lb.*.task_definition
      ),
      0
    )
  }"

  ecs_service_desired_count = "${
    element(
      concat(
        aws_ecs_service.fargate_with_lb.*.desired_count,
        aws_ecs_service.fargate_without_lb.*.desired_count
      ),
      0
    )
  }"
}

resource "null_resource" "ecs_deployment_check" {
  count = "${var.enable_ecs_deployment_check ? 1 : 0}"

  triggers = {
    ecs_service_arn         = "${local.ecs_service_arn}"
    ecs_task_definition_arn = "${local.ecs_service_task_definition_arn}"
    desired_count           = "${local.ecs_service_desired_count}"
  }

  provisioner "local-exec" {
    command = <<EOF
${module.ecs_deployment_check_bin.path} \
  --loglevel ${var.deployment_check_loglevel} \
  ${var.is_associated_with_lb ? "" : "--no-loadbalancer"} \
  --ecs-cluster-arn ${var.cluster_arn} \
  --ecs-service-arn ${local.ecs_service_arn} \
  --ecs-task-definition-arn ${local.ecs_service_task_definition_arn} \
  --aws-region ${data.aws_arn.ecs_service.region} \
  --min-active-task-count ${local.ecs_service_desired_count} \
  --check-timeout-seconds ${var.deployment_check_timeout_seconds}
EOF
  }
}

# Build the path to the deployment check binary
module "ecs_deployment_check_bin" {
  source = "git::git@github.com:gruntwork-io/package-terraform-utilities.git//modules/join-path?ref=v0.0.3"

  path_parts = ["${path.module}", "..", "ecs-deploy-check-binaries", "bin", "check-ecs-service-deployment"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE FARGATE TASK DEFINITION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "task" {
  family                = "${var.service_name}"
  container_definitions = "${var.container_definitions}"
  task_role_arn         = "${aws_iam_role.fargate_task_role.arn}"
  execution_role_arn    = "${aws_iam_role.fargate_task_execution_role.arn}"

  # This must always to be set to awsvpc for Fargate
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # For Fargate CPU and Memory must be defined here and not in the container definition file
  cpu    = "${var.cpu}"
  memory = "${var.memory}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM ROLE FOR THE FARGATE TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "fargate_task_role" {
  name               = "${var.service_name}-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.fargate_task_policy_document.json}"
}

data "aws_iam_policy_document" "fargate_task_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM POLICY AND EXECUTION ROLE TO ALLOW FARGATE TASK MAKE CLOUDWATCH REQUESTS AND PULL IMAGES FROM ECR
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "fargate_task_execution_role" {
  name               = "${var.service_name}-task-execution-role"
  assume_role_policy = "${data.aws_iam_policy_document.fargate_task_policy_document.json}"
}

resource "aws_iam_policy" "fargate_task_execution_policy" {
  name   = "${var.service_name}-task-excution-policy"
  policy = "${data.aws_iam_policy_document.fargate_task_execution_policy_document.json}"
}

data "aws_iam_policy_document" "fargate_task_execution_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy_attachment" "task_execution_policy_attachment" {
  name       = "${var.service_name}-task-execution"
  policy_arn = "${aws_iam_policy.fargate_task_execution_policy.arn}"
  roles      = ["${aws_iam_role.fargate_task_execution_role.name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE FARGATE CLUSTER INSTANCE SECURITY GROUP
# Limits which ports are allowed inbound and outbound. We export the security group id as an output so users of this
# module can add their own custom rules.
# ---------------------------------------------------------------------------------------------------------------------

# Note that we do not define ingress and egress rules inline. This is because consumers of this terraform module might
# want to add arbitrary rules to this security group. See:
# https://www.terraform.io/docs/providers/aws/r/security_group.html.
resource "aws_security_group" "fargate" {
  name        = "${var.service_name}-cluster"
  description = "For Fargate Network Interfaces in the ECS Cluster."
  vpc_id      = "${var.vpc_id}"
  tags        = "${var.custom_tags_security_group}"
}

# Allow all outbound traffic from the ECS Cluster
resource "aws_security_group_rule" "allow_outbound_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.fargate.id}"
}

resource "aws_security_group_rule" "allow_inbound_from_cidr_blocks" {
  count = "${signum(length(var.allow_inbound_from_cidr_blocks))}"

  type      = "ingress"
  from_port = "${var.from_port}"
  to_port   = "${var.to_port}"
  protocol  = "${var.protocol}"

  cidr_blocks       = ["${var.allow_inbound_from_cidr_blocks}"]
  security_group_id = "${aws_security_group.fargate.id}"
}

resource "aws_security_group_rule" "allow_inbound_from_security_groups" {
  count = "${length(var.allow_inbound_from_security_group_ids)}"

  type      = "ingress"
  from_port = "${var.from_port}"
  to_port   = "${var.to_port}"
  protocol  = "${var.protocol}"

  source_security_group_id = "${element(var.allow_inbound_from_security_group_ids, count.index)}"
  security_group_id        = "${aws_security_group.fargate.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# FIGURE OUT LOAD BALANCER TYPE FROM ARN
# Use the generated ARN to determine whether load balancer is ALB or NLB. ALB has the '/app/' path in its fully
# qualified ARN while an NLB has the '/net/' path in its fully qualified ARN
# ---------------------------------------------------------------------------------------------------------------------
locals {
  is_alb = "${contains(split("/", var.load_balancer_arn), "app") ? true : false}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LOAD BALANCER TARGET GROUP
# - An LB sends requests to one or more Targets (containers) contained in a Target Group. Typically, a Target Group is
#   scoped to the level of an Fargate Service, so we create one here.
# - The port number listed below in the aws_lb_target_group refers to the default port to which the LB will route traffic,
#   but because this value will be overridden by each container instance that boots up, the actual value doesn't matter.
# ---------------------------------------------------------------------------------------------------------------------

# - Note that the port 80 specified below is simply the default port for the Target Group. When a Docker container
#   actually launches, the actual port will be chosen dynamically, so the value specified below is arbitrary.
# NOTE: This will only be created if var.is_associated_with_lb is true
resource "aws_lb_target_group" "fargate_service" {
  count = "${var.is_associated_with_lb}"

  name        = "${var.service_name}"
  port        = 80
  protocol    = "${local.is_alb ? var.alb_target_group_protocol : "TCP" }"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"

  deregistration_delay = "${var.lb_target_group_deregistration_delay}"

  # Potential workaround for https://github.com/hashicorp/terraform/issues/12634#issuecomment-363849290
  depends_on = ["null_resource.lb_exists"]

  health_check {
    interval          = "${var.health_check_interval}"
    path              = "${local.is_alb ? var.health_check_path : "" }"
    port              = "${var.health_check_port}"
    protocol          = "${local.is_alb ? var.health_check_protocol : "TCP" }"
    healthy_threshold = "${var.health_check_healthy_threshold}"

    # unhealthy_threshold must be the same as healthy_threshold for an NLB
    unhealthy_threshold = "${local.is_alb ? var.health_check_unhealthy_threshold : var.health_check_healthy_threshold }"
    matcher             = "${local.is_alb ? var.health_check_matcher : "" }"
  }

  stickiness {
    type            = "${var.alb_sticky_session_type}"
    cookie_duration = "${var.alb_sticky_session_cookie_duration}"
    enabled         = "${local.is_alb ? var.use_alb_sticky_sessions : false}"
  }
}

# Due to a Terraform bug (https://github.com/hashicorp/terraform/issues/12634), the ALB must be created before the Fargate
# Service is created. But Terraform does not allow a resource in a module to explicitly depend on a resource outside
# that module, so we "fake" that behavior by creating this null_resource, and now any resources that would want to depend
# on the ALB can instead directly depend on this resource.
resource "null_resource" "lb_exists" {
  triggers {
    alb_name = "${var.load_balancer_arn}"
  }
}
