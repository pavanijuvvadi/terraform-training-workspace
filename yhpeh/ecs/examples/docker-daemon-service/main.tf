# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A DOCKER DAEMON SERVICE
# These templates show an example of how to run a Docker app on as a Daemon Service on ECS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"

  # Only this AWS Account ID may be operated on by this template
  allowed_account_ids = ["${var.aws_account_id}"]
}

# -------------------------no--------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "container_definition" {
  template = "${file("${path.module}/containers/datadog-agent-ecs.json")}"

  vars {
    cpu     = "${var.cpu}"
    memory  = "${var.memory}"
    api_key = "${var.api_key}"

    command = "[${join(",", formatlist("\"%s\"", var.container_command))}]"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS SERVICE TO RUN MY ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_daemon_service" {
  source = "../../modules/ecs-daemon-service"

  service_name                   = "${var.service_name}"
  environment_name               = "${var.environment_name}"
  ecs_cluster_arn                = "${var.ecs_cluster_arn}"
  ecs_task_container_definitions = "${data.template_file.container_definition.rendered}"

  enable_ecs_deployment_check      = "${var.enable_ecs_deployment_check}"
  deployment_check_timeout_seconds = "${var.deployment_check_timeout_seconds}"

  volumes = [
    {
      name      = "docker_sock"
      host_path = "/var/run/docker.sock"
    },
    {
      name      = "proc"
      host_path = "/proc/"
    },
    {
      name      = "cgroup"
      host_path = "/cgroup/"
    },
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ADDITIONAL POLICIES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "iam_policy" {
  name = "datadog-agent-policy"
  role = "${module.ecs_daemon_service.ecs_task_iam_role_name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:RegisterContainerInstance",
                "ecs:DeregisterContainerInstance",
                "ecs:DiscoverPollEndpoint",
                "ecs:Submit*",
                "ecs:Poll",
                "ecs:StartTask",
                "ecs:StartTelemetrySession"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}
