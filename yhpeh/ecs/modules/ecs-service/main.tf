# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN EC2 CONTAINER SERVICE (ECS) SERVICE
# These templates create an ECS Service which runs one or more related Docker containers in fault-tolerant way. This
# includes:
# - The ECS Service itself
# - An optional association with an Elastic Load Balancer (ELB)
# - IAM roles and policies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

# Terraform 0.8.2 introduced a regression (https://github.com/hashicorp/terraform/issues/10919) where app_autoscaling_target
# is no longer usable.
terraform {
  required_version = "~> 0.8, != 0.8.2"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS SERVICE
# Note that we have four aws_ecs_service resources: one with an ELB but no auto scaling, one with an ELB and auto
# scaling, one with no ELB and no auto scaling, and one with no ELB and auto scaling. Only ONE of these will
# be created, based on the values the user of this module set for var.is_associated_with_elb and var.use_auto_scaling.
# See the count parameter in each resource to see how we are simulating an if-statement in Terraform.
#
# The reason we have to create four resources to create these four cases is because the resources differ based on
# inline blocks (load_balancer in one case and lifecycle in the other) and there is no way to conditionally include
# an inline block. Moreover, the lifecycle ignore_changes property allows no interpolation, so our only option is lots
# of duplicated resources and clever count parameters to ensure only one gets created.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "service_with_elb_without_auto_scaling" {
  count = "${var.is_associated_with_elb * (1 - var.use_auto_scaling)}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  # This role is required for ECS Services to be able to talk to the ELB. The depends_on is required according to the
  # Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html
  iam_role = "${aws_iam_role.ecs_service_role.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_policy"]

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  load_balancer {
    elb_name       = "${var.elb_name}"
    container_name = "${var.elb_container_name}"
    container_port = "${var.elb_container_port}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }
}

resource "aws_ecs_service" "service_with_elb_with_auto_scaling" {
  count = "${var.is_associated_with_elb * var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  # This role is required for ECS Services to be able to talk to the ELB. The depends_on is required according to the
  # Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html
  iam_role = "${aws_iam_role.ecs_service_role.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_policy"]

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  load_balancer {
    elb_name       = "${var.elb_name}"
    container_name = "${var.elb_container_name}"
    container_port = "${var.elb_container_port}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  # When the use_auto_scaling property is set to true, we need to tell the ECS Service to ignore the desired_count
  # property, as the number of instances will be controlled by auto scaling. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10308
  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_service" "service_without_elb_without_auto_scaling" {
  count = "${(1 - var.is_associated_with_elb) * (1 - var.use_auto_scaling)}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }

  desired_count                      = "${var.desired_number_of_tasks}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"
}

resource "aws_ecs_service" "service_without_elb_with_auto_scaling" {
  count = "${(1 - var.is_associated_with_elb) * var.use_auto_scaling}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  placement_strategy {
    type  = "${var.placement_strategy_type}"
    field = "${var.placement_strategy_field}"
  }

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
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

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS SERVICE CANARIES
# We create a canary version of the ECS Service that can be used to test deployment of a new version of a Docker
# container on a small number of ECS Tasks (usually just one) before deploying it across all ECS Tasks.
#
# Note that we have two aws_ecs_service canary resources: service_with_elb and service_without_elb. Only ONE of these
# will be created, based on whether the user of this module specified a load_balancer_id. See the count parameter in
# each resource to see how we are simulating an if-statement in Terraform.
#
# Note that we do NOT need two more permutations of the canaries for auto scaling, since you only ever run zero or one
# canaries.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "service_with_elb_canary" {
  # This count parameter does two things. First, it ensures we only create this resource if the user has requested at
  # least one canary task to run. Second, we only create this version of the aws_ecs_service if the user wants to
  # associate their ECS Service with an ELB. Otherwise, we create service_without_elb_canary.
  count = "${signum(var.desired_number_of_canary_tasks_to_run * var.is_associated_with_elb)}"

  name            = "${var.service_name}-canary"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task_canary.arn}"

  # This role is required for ECS Services to be able to talk to the ELB. The depends_on is required according to the
  # Terraform docs: https://www.terraform.io/docs/providers/aws/r/ecs_service.html
  iam_role = "${aws_iam_role.ecs_service_role.arn}"

  depends_on = ["aws_iam_role_policy.ecs_service_policy"]

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
    elb_name       = "${var.elb_name}"
    container_name = "${var.elb_container_name}"
    container_port = "${var.elb_container_port}"
  }

  # Workaround for a bug where Terraform sometimes doesn't wait long enough for the service to propagate.
  provisioner "local-exec" {
    command = "echo 'Sleeping for 30 seconds to work around ecs service creation bug in Terraform' && sleep 30"
  }
}

resource "aws_ecs_service" "service_without_elb_canary" {
  # This count parameter does two things. First, it ensures we only create this resource if the user has requested at
  # least one canary task to run. Second, we only create this version of the aws_ecs_service if the user does not
  # want to assoicate their Service with an ELB. Otherwise, we create service_with_elb_canary.
  count = "${signum(var.desired_number_of_canary_tasks_to_run * (1 - var.is_associated_with_elb))}"

  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task_canary.arn}"

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
        aws_ecs_service.service_with_elb_without_auto_scaling.*.id,
        aws_ecs_service.service_with_elb_with_auto_scaling.*.id,
        aws_ecs_service.service_without_elb_without_auto_scaling.*.id,
        aws_ecs_service.service_without_elb_with_auto_scaling.*.id
      ),
      0
    )
  }"

  ecs_service_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_elb_without_auto_scaling.*.task_definition,
        aws_ecs_service.service_with_elb_with_auto_scaling.*.task_definition,
        aws_ecs_service.service_without_elb_without_auto_scaling.*.task_definition,
        aws_ecs_service.service_without_elb_with_auto_scaling.*.task_definition
      ),
      0
    )
  }"

  ecs_service_desired_count = "${
    element(
      concat(
        aws_ecs_service.service_with_elb_without_auto_scaling.*.desired_count,
        aws_ecs_service.service_with_elb_with_auto_scaling.*.desired_count,
        aws_ecs_service.service_without_elb_without_auto_scaling.*.desired_count,
        aws_ecs_service.service_without_elb_with_auto_scaling.*.desired_count
      ),
      0
    )
  }"

  # We use the fancy element(concat()) functions because this aws_ecs_task_definition resource may not exist.
  ecs_service_canary_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_elb_canary.*.id,
        aws_ecs_service.service_without_elb_canary.*.id,
        list("")
      ),
      0
    )
  }"

  ecs_service_canary_task_definition_arn = "${
    element(
      concat(
        aws_ecs_service.service_with_elb_canary.*.task_definition,
        aws_ecs_service.service_without_elb_canary.*.task_definition,
        list("")
      ),
      0
    )
  }"

  ecs_service_canary_desired_count = "${
    element(
      concat(
        aws_ecs_service.service_with_elb_canary.*.desired_count,
        aws_ecs_service.service_without_elb_canary.*.desired_count,
        list("")
      ),
      0
    )
  }"

  # Even with ELB, we still skip loadbalancer check because the binary does not
  # support classic ELB checks.
  check_common_args = <<EOF
--loglevel ${var.deployment_check_loglevel} \
--aws-region ${data.aws_arn.ecs_service.region} \
--ecs-cluster-arn ${var.ecs_cluster_arn} \
--no-loadbalancer \
--check-timeout-seconds ${var.deployment_check_timeout_seconds}
EOF
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
  --ecs-service-arn ${local.ecs_service_arn} \
  --ecs-task-definition-arn ${local.ecs_service_task_definition_arn} \
  --min-active-task-count ${local.ecs_service_desired_count} \
  ${local.check_common_args}
EOF
  }
}

resource "null_resource" "ecs_canary_deployment_check" {
  count = "${
    var.desired_number_of_canary_tasks_to_run > 0 && var.enable_ecs_deployment_check ? 1 : 0
  }"

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
# CREATE AN IAM ROLE FOR THE SERVICE
# We output the id of this IAM role in case the module user wants to attach custom IAM policies to it. Note that the
# role is only created and used if this ECS Service is being used with an ELB.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_service_role" {
  # The reason we use a count here is to ensure this resource is only created if var.is_associated_with_elb is true. In
  # Terraform, a boolean true is a 1 and a boolean false is a 0, so only if var.is_associated_with_elb is true do we create
  # this resource.
  count = "${signum(var.is_associated_with_elb)}"

  name               = "${var.service_name}-${var.environment_name}"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM POLICY THAT ALLOWS THE SERVICE TO TALK TO THE ELB
# Note that this policy is only created and used if this ECS Service is being used with an ELB.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecs_service_policy" {
  # The reason we use a count here is to ensure this resource is only created if var.is_associated_with_elb is true. In
  # Terraform, a boolean true is a 1 and a boolean false is a 0, so only if var.is_associated_with_elb is true do we create
  # this resource.
  count = "${signum(var.is_associated_with_elb)}"

  name   = "${var.service_name}-ecs-service-policy"
  role   = "${aws_iam_role.ecs_service_role.id}"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
    ]

    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM ROLE FOR AUTO SCALING THE ECS SERVICE
# For details, see: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/autoscale_IAM_role.html
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_service_autoscaling_role" {
  count = "${var.use_auto_scaling}"

  name               = "${var.service_name}-${var.environment_name}-autoscaling"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_role.json}"
}

data "aws_iam_policy_document" "ecs_service_autoscaling_role" {
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

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM POLICY THAT ALLOWS THE SERVICE TO PERFORM AUTOSCALING ACTIONS
# For details, see: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/autoscale_IAM_role.html
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecs_service_autoscaling_policy" {
  count = "${var.use_auto_scaling}"

  name   = "${var.service_name}-ecs-service-autoscaling-policy"
  role   = "${aws_iam_role.ecs_service_autoscaling_role.id}"
  policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_policy.json}"
}

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
