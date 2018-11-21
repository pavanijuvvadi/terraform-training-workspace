# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN ECS CONTAINER DAEMON SERVICE
# These templates create an ECS Daemon Service which runs one or more related Docker containers in fault-tolerant way. This
# includes:
# - The ECS Service itself
# - An optional association with an Elastic Load Balancer (ELB)
# - IAM roles and policies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# SET TERRAFORM REQUIREMENTS FOR RUNNING THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS DAEMON SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "daemon_service" {
  name            = "${var.service_name}"
  cluster         = "${var.ecs_cluster_arn}"
  task_definition = "${aws_ecs_task_definition.task.arn}"

  # The reseaon why we have a separate module for DAEMON is discussed here:
  # https://github.com/gruntwork-io/module-ecs/issues/77
  #
  # TLDR: introducing the DAEMON in the other ecs modules would cause breaking changes
  # and lots of conditional logic.
  scheduling_strategy = "DAEMON"

  placement_constraints {
    type       = "${var.placement_constraint_type}"
    expression = "${var.placement_constraint_expression}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CHECK THE ECS SERVICE DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_arn" "ecs_service" {
  arn = "${aws_ecs_service.daemon_service.id}"
}

resource "null_resource" "ecs_deployment_check" {
  count = "${var.enable_ecs_deployment_check ? 1 : 0}"

  triggers = {
    ecs_service_arn         = "${aws_ecs_service.daemon_service.id}"
    ecs_task_definition_arn = "${aws_ecs_service.daemon_service.task_definition}"
  }

  provisioner "local-exec" {
    command = <<EOF
${module.ecs_deployment_check_bin.path} \
  --loglevel ${var.deployment_check_loglevel} \
  --ecs-cluster-arn ${var.ecs_cluster_arn} \
  --ecs-service-arn ${aws_ecs_service.daemon_service.id} \
  --ecs-task-definition-arn ${aws_ecs_task_definition.task.arn} \
  --aws-region ${data.aws_arn.ecs_service.region} \
  --check-timeout-seconds ${var.deployment_check_timeout_seconds} \
  --daemon-check --no-loadbalancer
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

  volume = "${var.volumes}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK ROLE
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
