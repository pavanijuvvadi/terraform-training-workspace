# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A DOCKER APP
# These templates show an example of how to run a Docker app on top of Amazon's Fargate Service
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CLUSTER TO WHICH THE FARGATE SERVICE WILL BE DEPLOYED TO
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "fargate_cluster" {
  name = "${var.service_name}-example"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A FARGATE SERVICE TO RUN MY ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

module "fargate_service" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-fargate?ref=v1.0.8"
  source = "../../modules/ecs-fargate"

  service_name = "${var.service_name}"
  cluster_arn  = "${aws_ecs_cluster.fargate_cluster.arn}"
  vpc_id       = "${data.aws_vpc.default.id}"
  subnet_ids   = "${data.aws_subnet_ids.default.ids}"

  assign_public_ip        = true
  desired_number_of_tasks = "${var.desired_number_of_tasks}"

  // Allow inbound connections from any IP on all TCP ports
  allow_inbound_from_cidr_blocks        = ["0.0.0.0/0"]
  allow_inbound_from_security_group_ids = []
  protocol                              = "tcp"
  from_port                             = 0
  to_port                               = 65535

  container_definitions = "${data.template_file.container_definition.rendered}"

  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size.
  # Specify memory in MB

  cpu                              = 256
  memory                           = 512
  enable_ecs_deployment_check      = "${var.enable_ecs_deployment_check}"
  deployment_check_timeout_seconds = "${var.deployment_check_timeout_seconds}"
}

# This template_file defines the Docker containers we want to run in our ECS Task
data "template_file" "container_definition" {
  template = "${file("${path.module}/containers/container-definition.json")}"

  vars {
    container_name = "${var.service_name}"

    # For this example, we run the Docker container defined under examples/example-docker-image.
    image        = "gruntwork/docker-test-webapp"
    version      = "latest"
    server_text  = "${var.server_text}"
    aws_region   = "${var.aws_region}"
    s3_test_file = "s3://${aws_s3_bucket.s3_test_bucket.id}/${var.s3_test_file_name}"

    cpu    = 256
    memory = 512

    awslogs_group  = "${var.service_name}"
    awslogs_region = "${var.aws_region}"
    awslogs_prefix = "${var.service_name}"

    container_http_port = "${var.http_port}"

    command = "[${join(",", formatlist("\"%s\"", var.container_command))}]"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET FOR TESTING PURPOSES ONLY
# We upload a simple text file into this bucket. The ECS Task will try to download the file and display its contents.
# This is used to verify that we are correctly attaching an IAM Policy to the ECS Task that gives it the permissions to
# access the S3 bucket.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "s3_test_bucket" {
  bucket = "${lower(var.service_name)}-test-s3-bucket"
  region = "${var.aws_region}"
}

resource "aws_s3_bucket_object" "s3_test_file" {
  bucket  = "${aws_s3_bucket.s3_test_bucket.id}"
  key     = "${var.s3_test_file_name}"
  content = "world!"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY TO THE TASK THAT ALLOWS THE ECS SERVICE TO ACCESS THE S3 BUCKET FOR TESTING PURPOSES
# The Docker container in our ECS Task will need this policy to download a file from an S3 bucket. We use this solely
# to test that the IAM policy is properly attached to the ECS Task.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_policy" "access_test_s3_bucket" {
  name   = "${var.service_name}-s3-test-bucket-access"
  policy = "${data.aws_iam_policy_document.access_test_s3_bucket.json}"
}

data "aws_iam_policy_document" "access_test_s3_bucket" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_test_bucket.arn}/${var.s3_test_file_name}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.s3_test_bucket.arn}"]
  }
}

resource "aws_iam_policy_attachment" "access_test_s3_bucket" {
  name       = "${var.service_name}-s3-test-bucket-access"
  policy_arn = "${aws_iam_policy.access_test_s3_bucket.arn}"
  roles      = ["${module.fargate_service.fargate_task_iam_role_name}"]
}

# --------------------------------------------------------------------------------------------------------------------
# GET VPC AND SUBNET INFO FROM TERRAFORM DATA SOURCE
# --------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE AN EXAMPLE CLOUDWATCH LOG GROUP
# --------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "log_group_example" {
  name = "${var.service_name}"
}
