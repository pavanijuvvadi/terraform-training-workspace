# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN ECS SERVICE TO BE FRONTED BY AN APPLICATION LOAD BALANCER
# This template creates an ECS Service that will use an existing ALB as its load balancer. It optionally permits setup
# of AutoScaling. Note that we create the ALB Target Group as part of this module since this will be scoped to an ECS
# Service. We do NOT create ALB Listener Rules in this module; those must be created external to this module.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.3"
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

locals {
  alb_target_group_name = "${var.alb_target_group_name == "" ? var.service_name: var.alb_target_group_name}"
}

# Create the ECS Service for use *without* Auto Scaling
resource "aws_ecs_service" "service_without_auto_scaling" {
  count = "${1 - var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  # This role is required for ECS Services to be able to talk to the ALB.
  # - We depend on aws_iam_role_policy because it's required per Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html.
  # - We depend on null_resource.alb_exists to avoid this Terraform bug: https://github.com/hashicorp/terraform/issues/12634
  iam_role = "${aws_iam_role.ecs_service_scheduler.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_scheduler", "null_resource.alb_exists"]

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  load_balancer {
    target_group_arn = "${data.template_file.alb_target_group_arn.rendered}"
    container_name   = "${var.alb_container_name}"
    container_port   = "${var.alb_container_port}"
  }
}

# Create the ECS Service for use *with* Auto Scaling
resource "aws_ecs_service" "service_with_auto_scaling" {
  count = "${var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  # This role is required for ECS Services to be able to talk to the ALB.
  # - We depend on aws_iam_role_policy because it's required per Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html.
  # - We depend on null_resource.alb_exists to avoid this Terraform bug: https://github.com/hashicorp/terraform/issues/12634
  iam_role = "${aws_iam_role.ecs_service_scheduler.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_scheduler", "null_resource.alb_exists"]

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  load_balancer {
    target_group_arn = "${data.template_file.alb_target_group_arn.rendered}"
    container_name   = "${var.alb_container_name}"
    container_port   = "${var.alb_container_port}"
  }

  # When the use_auto_scaling property is set to true, we need to tell the ECS Service to ignore the desired_count
  # property, as the number of instances will be controlled by auto scaling. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10308
  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CHECK THE ECS SERVICE DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  ecs_service_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_auto_scaling.*.id,
        aws_ecs_service.service_without_auto_scaling.*.id
      ),
      0
    )
  }"

  ecs_service_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_auto_scaling.*.task_definition,
        aws_ecs_service.service_without_auto_scaling.*.task_definition
      ),
      0
    )
  }"

  ecs_service_desired_count = "${
    element(
      concat(
        aws_ecs_service.service_with_auto_scaling.*.desired_count,
        aws_ecs_service.service_without_auto_scaling.*.desired_count
      ),
      0
    )
  }"

  # We use the fancy element(concat()) functions because the canary resources may not exist.
  ecs_service_canary_arn = "${
    element(
      concat(
        aws_ecs_service.service_canary.*.id,
        list("")
      ),
      0
    )
  }"

  ecs_service_canary_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.service_canary.*.task_definition,
        list("")
      ),
      0
    )
  }"

  ecs_service_canary_desired_count = "${
    element(
      concat(
        aws_ecs_service.service_canary.*.desired_count,
        list("")
      ),
      0
    )
  }"

  check_common_args = <<EOF
--loglevel ${var.deployment_check_loglevel} \
--aws-region ${var.aws_region} \
--ecs-cluster-arn ${var.ecs_cluster_arn} \
--check-timeout-seconds ${var.deployment_check_timeout_seconds}
EOF
}

resource "null_resource" "ecs_deployment_check" {
  count = "${var.enable_ecs_deployment_check ? 1 : 0}"

  // Run check if anything is deployed to the service
  triggers = {
    ecs_service_arn         = "${local.ecs_service_arn}"
    ecs_task_definition_arn = "${local.ecs_service_task_definition_arn}"
    desired_count           = "${local.ecs_service_desired_count}"
  }

  provisioner "local-exec" {
    command = <<EOF
${module.ecs_deployment_check_bin.path} \
  --ecs-service-arn ${local.ecs_service_arn} \
  --ecs-task-definition-arn ${local.ecs_service_task_definition_arn} \
  --min-active-task-count ${local.ecs_service_desired_count} \
  ${local.check_common_args}
EOF
  }
}

resource "null_resource" "ecs_canary_deployment_check" {
  # Only check the canary if the user is requesting one
  count = "${
    var.desired_number_of_canary_tasks_to_run > 0 && var.enable_ecs_deployment_check ? 1 : 0
  }"

  // Run check if anything is deployed to the service
  triggers = {
    ecs_service_arn         = "${local.ecs_service_canary_arn}"
    ecs_task_definition_arn = "${local.ecs_service_canary_task_definition_arn}"
    desired_count           = "${local.ecs_service_canary_desired_count}"
  }

  provisioner "local-exec" {
    command = <<EOF
${module.ecs_deployment_check_bin.path} \
  --ecs-service-arn ${local.ecs_service_canary_arn} \
  --ecs-task-definition-arn ${local.ecs_service_canary_task_definition_arn} \
  --min-active-task-count ${local.ecs_service_canary_desired_count} \
  ${local.check_common_args}
EOF
  }
}

# Build the path to the deployment check binary
module "ecs_deployment_check_bin" {
  source = "git::git@github.com:gruntwork-io/package-terraform-utilities.git//modules/join-path?ref=v0.0.3"

  path_parts = ["${path.module}", "..", "ecs-deploy-check-binaries", "bin", "check-ecs-service-deployment"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK DEFINITION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "task" {
  family                = "${var.service_name}"
  container_definitions = "${var.ecs_task_container_definitions}"
  task_role_arn         = "${aws_iam_role.ecs_task.arn}"
  network_mode          = "${var.ecs_task_definition_network_mode}"
  volume                = "${var.volumes}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ALB TARGET GROUP
# - An ALB sends requests to one or more Targets (containers) contained in a Target Group. Typically, a Target Group is
#   scoped to the level of an ECS Service, so we create one here.
# - Unfortunately, in order to make the use of Sticky Sessions optional, we must define two separate Terraform resources
#   and use "count" to decide which one will be created. This is because "stickiness" is an inline property and cannot be
#   dynamically added or removed.
# - The port number listed below in each aws_alb_targe_group refers to the default port to which the ALB will route traffic,
#   but because this value will be overriddenen by each container instance that boots up, the actual value doesn't matter.
# ---------------------------------------------------------------------------------------------------------------------

# Create the ALB Target Group that does NOT use Sticky Sessions.
# - Note that the port 80 specified below is simply the default port for the Target Group. When a Docker container
#   actually launches, the actual port will be chosen dynamically, so the value specified below is arbitrary.
# NOTE: This will only be created if var.use_alb_sticky_sessions == false
resource "aws_alb_target_group" "ecs_service_without_sticky_sessions" {
  count = "${1 - var.use_alb_sticky_sessions}"

  name     = "${local.alb_target_group_name}"
  port     = 80
  protocol = "${var.alb_target_group_protocol}"
  vpc_id   = "${var.vpc_id}"

  deregistration_delay = "${var.alb_target_group_deregistration_delay}"

  # Potential workaround for https://github.com/hashicorp/terraform/issues/12634#issuecomment-363849290
  depends_on = ["null_resource.alb_exists"]

  health_check {
    interval            = "${var.health_check_interval}"
    path                = "${var.health_check_path}"
    port                = "${var.health_check_port}"
    protocol            = "${var.health_check_protocol}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    matcher             = "${var.health_check_matcher}"
  }
}

# Create the ALB Target Group that uses Sticky Sessions.
# - Note that the port 80 specified below is simply the default port for the Target Group. When a Docker container
#   actually launches, the actual port will be chosen dynamically, so the value specified below is arbitrary.
# NOTE: This will only be created if var.use_alb_sticky_sessions == true
resource "aws_alb_target_group" "ecs_service_with_sticky_sessions" {
  count = "${var.use_alb_sticky_sessions}"

  name     = "${local.alb_target_group_name}"
  port     = 80
  protocol = "${var.alb_target_group_protocol}"
  vpc_id   = "${var.vpc_id}"

  deregistration_delay = "${var.alb_target_group_deregistration_delay}"

  # Potential workaround for https://github.com/hashicorp/terraform/issues/12634#issuecomment-363849290
  depends_on = ["null_resource.alb_exists"]

  health_check {
    interval            = "${var.health_check_interval}"
    path                = "${var.health_check_path}"
    port                = "${var.health_check_port}"
    protocol            = "${var.health_check_protocol}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    matcher             = "${var.health_check_matcher}"
  }

  stickiness {
    type            = "${var.alb_sticky_session_type}"
    cookie_duration = "${var.alb_sticky_session_cookie_duration}"
  }
}

# Note that no ALB Listener Rules are defined by this module! As a result, you'll need to add those ALB Listener Rules
# somewhere external to this module. Most likely, this will be in the code that calls this module. We made this decision
# because trying to capture the full range of ALB Listener Rule functionality in this module's API proved more confusing
# than helpful.

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS SERVICE SCHEDULER IAM ROLE
# Per https://goo.gl/mv8bJ4, the ECS Service Scheduler IAM Role is required by an ALB or ELB to register/deregister
# container instances on it. This IAM Role should not be used to assign custom permissions so we do not export its ID.
# ---------------------------------------------------------------------------------------------------------------------

# Create the ECS Service Scheduler IAM Role
resource "aws_iam_role" "ecs_service_scheduler" {
  name               = "${var.service_name}-${var.environment_name}-service-scheduler"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_scheduler_assume_role.json}"
}

# Define the Assume Role IAM Policy Document for the ECS Service Scheduler IAM Role
data "aws_iam_policy_document" "ecs_service_scheduler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

# Create an IAM Policy that allows the ECS Service to talk to the ALB
resource "aws_iam_role_policy" "ecs_service_scheduler" {
  name   = "${var.service_name}-ecs-service-scheduler-policy"
  role   = "${aws_iam_role.ecs_service_scheduler.name}"
  policy = "${data.aws_iam_policy_document.ecs_service_scheduler.json}"
}

# Define the IAM Policy as required per Per https://goo.gl/mv8bJ4.
data "aws_iam_policy_document" "ecs_service_scheduler" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
    ]

    resources = ["*"]
  }
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
# CREATE THE ECS SERVICE CANARY
# We create a canary version of the ECS Service that can be used to test deployment of a new version of a Docker
# container on a small number of ECS Tasks (usually just one) before deploying it across all ECS Tasks.
#
# Note that we do NOT need two permutations of the canaries for auto scaling, since you will only every run a fixed
# number of canary ECS Tasks.
# ---------------------------------------------------------------------------------------------------------------------

# Create a separate ECS Service which will receive traffic from the same ALB.
resource "aws_ecs_service" "service_canary" {
  # This count parameter ensures we only create this resource if the user has requested at least one canary ECS Task to run.
  count = "${signum(var.desired_number_of_canary_tasks_to_run)}"

  name            = "${var.service_name}-canary"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task_canary.arn}"

  # This role is required for ECS Services to be able to talk to the ALB.
  # - We depend on aws_iam_role_policy because it's required per Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html.
  # - We depend on null_resource.alb_exists to avoid this Terraform bug: https://github.com/hashicorp/terraform/issues/12634
  iam_role = "${aws_iam_role.ecs_service_scheduler.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_scheduler", "null_resource.alb_exists"]

  desired_count                      = "${var.desired_number_of_canary_tasks_to_run}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  load_balancer {
    target_group_arn = "${data.template_file.alb_target_group_arn.rendered}"
    container_name   = "${var.alb_container_name}"
    container_port   = "${var.alb_container_port}"
  }

  # Workaround for a bug where Terraform sometimes doesn't wait long enough for the service to propagate.
  provisioner "local-exec" {
    command = "echo 'Sleeping for 30 seconds to work around ecs service creation bug in Terraform' && sleep 30"
  }
}

# Create a dedicated ECS Task specially for our canaries
resource "aws_ecs_task_definition" "task_canary" {
  # This count parameter ensures we only create this resource if the user has requested at least one canary ECS Task to run.
  count = "${signum(var.desired_number_of_canary_tasks_to_run)}"

  family                = "${var.service_name}"
  container_definitions = "${var.ecs_task_definition_canary}"
  task_role_arn         = "${aws_iam_role.ecs_task.arn}"
  network_mode          = "${var.ecs_task_definition_network_mode}"
  volume                = "${var.volumes}"
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
# All resources below are only created if var.use_auto_scaling is true.
# ---------------------------------------------------------------------------------------------------------------------

# Create an IAM Role to be used by the Amazon Autoscaling Service on the ECS Service
# For details, see: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/autoscale_IAM_role.html
resource "aws_iam_role" "ecs_service_autoscaling_role" {
  count = "${var.use_auto_scaling}"

  name               = "${var.service_name}-${var.environment_name}-autoscaling"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_role_trust_policy.json}"
}

# Create the Trust Policy as documented at http://docs.aws.amazon.com/AmazonECS/latest/developerguide/autoscale_IAM_role.html
data "aws_iam_policy_document" "ecs_service_autoscaling_role_trust_policy" {
  count = "${var.use_auto_scaling}"

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }
  }
}

# Create an IAM Policy that allows the ECS Service to perform Auto Scaling actions
# For details, see: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/autoscale_IAM_role.html
resource "aws_iam_role_policy" "ecs_service_autoscaling_policy" {
  count = "${var.use_auto_scaling}"

  name   = "enable-autoscaling"
  role   = "${aws_iam_role.ecs_service_autoscaling_role.name}"
  policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_policy.json}"
}

# Create the IAM Policy document that grants permissions to perform Auto Scaling actions
data "aws_iam_policy_document" "ecs_service_autoscaling_policy" {
  count = "${var.use_auto_scaling}"

  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:DescribeAlarms",
    ]

    resources = ["*"]
  }
}

# Create an App AutoScaling Target that allows us to add AutoScaling Policies to our ECS Service
resource "aws_appautoscaling_target" "appautoscaling_target" {
  count = "${var.use_auto_scaling}"

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  resource_id = "service/${var.ecs_cluster_name}/${var.service_name}"
  role_arn    = "${aws_iam_role.ecs_service_autoscaling_role.arn}"

  min_capacity = "${var.min_number_of_tasks}"
  max_capacity = "${var.max_number_of_tasks}"

  depends_on = ["aws_ecs_service.service_with_auto_scaling", "aws_ecs_service.service_without_auto_scaling", "aws_ecs_service.service_canary"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONVENIENCE VARIABLES
# Because we've got some conditional logic in this template, some values will depend on our properties. This section
# wraps such values in a nicer construct. In some cases, these variables help us avoid Terraform bugs.
# ---------------------------------------------------------------------------------------------------------------------

# The ALB Target Group's ARN depends on the value of var.use_alb_sticky_sessions
data "template_file" "alb_target_group_arn" {
  # This will return the ARN of the ALB Target Group that is actually created. It works as follows:
  # - Make a list of 1 value or 0 values for each of aws_alb_target_group.ecs_service_with_sticky_sessions and
  #   aws_alb_target_group.ecs_service_without_sticky_sessions by adding the glob (*) notation. Terraform will complain
  #   if we directly reference a resource property that doesn't exist, but it will permit us to turn a single resource
  #   into a list of 1 resource and "no resource" into an empty list.
  # - Concat these lists. concat(list-of-1-value, empty-list) == list-of-1-value
  # - Take the first element of list-of-1-value
  template = "${element(concat(aws_alb_target_group.ecs_service_with_sticky_sessions.*.arn, aws_alb_target_group.ecs_service_without_sticky_sessions.*.arn), 0)}"
}

# Due to a Terraform bug (https://github.com/hashicorp/terraform/issues/12634), the ALB must be created before the ECS
# Service is created. But Terraform does not allow a resource in a module to explicitly depend on a resource outside
# that module, so we "fake" that behavior by creating this null_resources, and now any resources that would want to depend
# on the ALB can instead directly depend on this resource.
resource "null_resource" "alb_exists" {
  triggers {
    alb_name = "${var.alb_arn}"
  }
}
