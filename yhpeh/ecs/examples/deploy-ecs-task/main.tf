# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A DOCKER CLUSTER AND CREATE AN ECS TASK DEFINITION
# This is an example of how to deploy a Docker cluster and create an ECS Task Definition. You can use the run-ecs-task
# script in the ecs-deploy module to run this ECS Task Definition in the ECS Cluster.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-cluster?ref=v1.0.8"
  source = "../../modules/ecs-cluster"

  cluster_name = "${var.ecs_cluster_name}"

  cluster_min_size = 2
  cluster_max_size = 2

  cluster_instance_ami          = "${var.ecs_cluster_instance_ami}"
  cluster_instance_type         = "t2.micro"
  cluster_instance_keypair_name = "${var.ecs_cluster_instance_keypair_name}"
  cluster_instance_user_data    = "${data.template_file.user_data.rendered}"

  vpc_id                           = "${data.aws_vpc.default.id}"
  vpc_subnet_ids                   = ["${data.aws_subnet.default.*.id}"]
  allow_ssh_from_security_group_id = ""
  allow_ssh                        = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON BOOT FOR EACH EC2 INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = "${file("${path.module}/user-data/user-data.sh")}"

  vars {
    ecs_cluster_name = "${var.ecs_cluster_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS TASK DEFINITION
# You can run this ECS Task Definition in the ECS Cluster by using the run-ecs-task script in the ecs-deploy module.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "example" {
  family                = "${var.ecs_cluster_name}-example-task-definition"
  container_definitions = "${data.template_file.ecs_task_container_definitions.rendered}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CONTAINER DEFINITIONS FOR THE ECS TASK DEFINITION
# This specifies what Docker container(s) to run in the ECS Task and the resources those container(s) need.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "ecs_task_container_definitions" {
  template = "${file("${path.module}/containers/container-definitions.json")}"

  vars {
    container_name = "${var.ecs_cluster_name}-example-container"

    image   = "${var.docker_image}"
    version = "${var.docker_image_version}"

    cpu    = 1024
    memory = 512

    command = "[${join(",", formatlist("\"%s\"", var.docker_image_command))}]"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# RUN THIS EXAMPLE IN THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we run all of the code in the Default VPC and Subnets. In real-world usage, you should
# always use a custom VPC with private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "all" {}

data "aws_subnet" "default" {
  count             = "${min(length(data.aws_availability_zones.all.names), 3)}"
  availability_zone = "${element(data.aws_availability_zones.all.names, count.index)}"
  default_for_az    = true
}
