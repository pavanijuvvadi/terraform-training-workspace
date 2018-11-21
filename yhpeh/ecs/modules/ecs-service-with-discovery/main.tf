# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN EC2 CONTAINER SERVICE (ECS) SERVICE WITH SERVICE DISCOVERY
# These templates create an ECS Service which runs one or more related Docker containers in fault-tolerant way. This
# includes:
# - The ECS Service itself
# - The task definition
# - A security group for the task
# - The service discovery
# We do not create the DNS namespace or the container definitions in this module, they have to be created externally.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.11.1"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK TO RUN THE DOCKER CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "task" {
  family                = "${var.service_name}-task-definition"
  container_definitions = "${var.ecs_task_container_definitions}"
  task_role_arn         = "${aws_iam_role.ecs_task.arn}"

  # For the moment, only tasks with awsvpc network mode will work with the ecs-service-with-discovery module
  network_mode = "awsvpc"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK IAM ROLE
# Per https://goo.gl/xKpEOp, the ECS Task IAM Role is where arbitrary IAM Policies (permissions) will be attached to
# support the unique needs of the particular ECS Service being created. Because the necessary IAM Policies depend on the
# particular ECS Service, we create the IAM Role here, but the permissions will be attached in the Terraform template
# that consumes this module.
# ---------------------------------------------------------------------------------------------------------------------

# Create the ECS Task IAM Role
resource "aws_iam_role" "ecs_task" {
  name               = "${var.service_name}-${var.environment_name}-task"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task.json}"
}

# Define the Assume Role IAM Policy Document for the ECS Service Scheduler IAM Role
data "aws_iam_policy_document" "ecs_task" {
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
# CREATE THE ECS SERVICE
# Note that we have two aws_ecs_service resources:
# - one with auto scaling
# - one without auto scaling
#
# The reason we have to create two resources is because the resources differ based on inline blocks (the lifecycle block)
# and there is no way to conditionally include an inline block. Moreover, the lifecycle ignore_changes property does not
# allow interpolation, so our only option is duplicated resources and clever count parameters to ensure only one gets created.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "service_with_auto_scaling" {
  count = "${var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  ordered_placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.discovery.arn}"
  }

  network_configuration {
    subnets         = ["${var.subnet_ids}"]
    security_groups = ["${concat(module.default_security_groups.list_value, var.custom_ecs_task_security_group_ids)}"]
  }

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  # When the use_auto_scaling property is set to true, we need to tell the ECS Service to ignore the desired_count
  # property, as the number of instances will be controlled by auto scaling. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10308
  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_service" "service_without_auto_scaling" {
  count = "${1 - var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  ordered_placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.discovery.arn}"
  }

  network_configuration {
    subnets         = ["${var.subnet_ids}"]
    security_groups = ["${concat(module.default_security_groups.list_value, var.custom_ecs_task_security_group_ids)}"]
  }

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"
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
        aws_ecs_service.service_with_auto_scaling.*.id,
        aws_ecs_service.service_without_auto_scaling.*.id,
        list("")
      ),
      0
    )
  }"

  ecs_service_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_auto_scaling.*.task_definition,
        aws_ecs_service.service_without_auto_scaling.*.task_definition,
        list("")
      ),
      0
    )
  }"

  ecs_service_desired_count = "${
    element(
      concat(
        aws_ecs_service.service_with_auto_scaling.*.desired_count,
        aws_ecs_service.service_without_auto_scaling.*.desired_count,
        list("")
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
  --no-loadbalancer \
  --ecs-cluster-arn ${var.ecs_cluster_arn} \
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
# CREATE THE ECS SERVICE DISCOVERY SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_service_discovery_service" "discovery" {
  name = "${var.discovery_name}"

  dns_config {
    namespace_id = "${var.discovery_namespace_id}"

    dns_records {
      ttl  = "${var.discovery_dns_ttl}"
      type = "A"
    }

    routing_policy = "${var.discovery_dns_routing_policy}"
  }

  health_check_custom_config {
    failure_threshold = "${var.discovery_custom_health_check_failure_threshold}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE AWSVPC TASK NETWORK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "ecs_task_security_group" {
  name   = "${var.service_name}-task"
  vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "allow_inbound_from_cidr_blocks_rule" {
  count             = "${signum(length(var.allow_inbound_from_cidr_blocks))}"
  security_group_id = "${aws_security_group.ecs_task_security_group.id}"
  type              = "ingress"
  from_port         = "${var.container_http_port}"
  to_port           = "${var.container_http_port}"
  protocol          = "tcp"
  cidr_blocks       = ["${var.allow_inbound_from_cidr_blocks}"]
}

resource "aws_security_group_rule" "allow_inbound_from_security_group_rule" {
  count                    = "${var.num_allow_inbound_security_groups}"
  security_group_id        = "${aws_security_group.ecs_task_security_group.id}"
  type                     = "ingress"
  from_port                = "${var.container_http_port}"
  to_port                  = "${var.container_http_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allow_inbound_from_security_group_ids, count.index)}"
}

module "default_security_groups" {
  source = "git::git@github.com:gruntwork-io/package-terraform-utilities.git//modules/intermediate-variable?ref=v0.0.1"

  list_value = ["${aws_security_group.ecs_task_security_group.id}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ALIAS RECORD FOR THE SERVICE, Only necessary for public namespaces
# The hosted zone ID of the original route53 domain is necessary
# aws_service_discovery_public_dns_namespace above creates another hosted zone, with a new hosted zone id
# It is created by the Auto Naming Service instead of the Registrar but it has the same domain name
# And then we can create an alias from the original hosted zone to the one recently created for this service
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "default" {
  count   = "${var.use_public_dns}"
  zone_id = "${var.original_public_route53_zone_id}"
  name    = "${var.service_name}.${var.discovery_namespace_name}"
  type    = "A"

  alias {
    name                   = "${var.service_name}.${var.discovery_namespace_name}"
    zone_id                = "${var.new_route53_zone_id}"
    evaluate_target_health = "${var.alias_record_evaluate_target_health}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE AUTO SCALING FOR THE ECS SERVICE
# Note that these resources *enable* Auto Scaling, but they won't actually activate any Auto Scaling policies. To do that,
# in the Terraform template that consumes this module, add the following resources:
# - aws_appautoscaling_policy.scale_out
# - aws_appautoscaling_policy.scale_in
# - aws_cloudwatch_metric_alarm.high_cpu_usage (or other CloudWatch alarm)
# - aws_cloudwatch_metric_alarm.low_cpu_usage (or other CloudWatch alarm)
#
# The resources below are only created if var.use_auto_scaling is true.
# ---------------------------------------------------------------------------------------------------------------------

# Create an App AutoScaling Target that allows us to add AutoScaling Policies to our ECS Service
resource "aws_appautoscaling_target" "appautoscaling_target" {
  count = "${var.use_auto_scaling}"

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  resource_id = "service/${var.ecs_cluster_name}/${var.service_name}"

  min_capacity = "${var.min_number_of_tasks}"
  max_capacity = "${var.max_number_of_tasks}"

  depends_on = ["aws_ecs_service.service_with_auto_scaling"]
}
