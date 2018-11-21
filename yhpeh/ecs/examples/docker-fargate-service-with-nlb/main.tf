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
  is_associated_with_lb   = true

  // Allow inbound connections from any IP on all TCP ports
  allow_inbound_from_cidr_blocks        = ["0.0.0.0/0"]
  allow_inbound_from_security_group_ids = []
  protocol                              = "tcp"
  from_port                             = 0
  to_port                               = 65535

  load_balancer_arn = "${module.nlb.nlb_arn}"

  lb_container_name = "${var.service_name}"
  lb_container_port = "${var.http_port}"

  container_definitions = "${data.template_file.container_definition.rendered}"

  # Give the container 15 seconds to boot before having the ALB start checking health
  health_check_grace_period_seconds = 15

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

    # Container and host mmust listen on the same port for Fargate
    container_http_port = "${var.http_port}"

    command = "[${join(",", formatlist("\"%s\"", var.container_command))}]"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN NLB TO ROUTE TRAFFIC ACROSS THE ECS TASKS
# Typically, this would be created once for use with many different ECS Services.
# ---------------------------------------------------------------------------------------------------------------------

module "nlb" {
  source = "git::git@github.com:gruntwork-io/module-load-balancer.git//modules/nlb?ref=v0.8.0"

  aws_region = "${var.aws_region}"

  nlb_name           = "${var.service_name}"
  environment_name   = "${var.environment_name}"
  is_internal_nlb    = false
  tcp_listener_ports = ["5000"]

  vpc_id         = "${data.aws_vpc.default.id}"
  vpc_subnet_ids = ["${data.aws_subnet_ids.default.ids}"]
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

# ---------------------------------------------------------------------------------------------------------------------
# GET VPC AND SUBNET INFO FROM TERRAFORM DATA SOURCE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "example" {
  load_balancer_arn = "${module.nlb.nlb_arn}"
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = "${module.fargate_service.target_group_arn}"
    type             = "forward"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ASSOCIATE A DNS RECORD WITH OUR NLB
# This way we can test the host-based routing properly.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "sample" {
  name = "${var.route53_hosted_zone_name}"
}

resource "aws_route53_record" "nlb_endpoint" {
  zone_id = "${data.aws_route53_zone.sample.zone_id}"
  name    = "${var.service_name}.${data.aws_route53_zone.sample.name}"
  type    = "A"

  alias {
    name                   = "${module.nlb.nlb_dns_name}"
    zone_id                = "${module.nlb.nlb_hosted_zone_id}"
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ROUTE53 DOMAIN NAME TO BE ASSOCIATED WITH THIS FARGATE SERVICE
# The Route53 Resource Record Set (DNS record) will point to the NLB.
# ---------------------------------------------------------------------------------------------------------------------

# Create a Route53 Private Hosted Zone ID
# In production, this template would be a poor place to create this resource, but we'll need it for testing purposes.
resource "aws_route53_zone" "for_testing" {
  name   = "${var.service_name}.nlbtest"
  vpc_id = "${data.aws_vpc.default.id}"
}

# Create a DNS Record in Route53 for the ECS Service
# - We are creating a Route53 "alias" record to take advantage of its unique benefits such as instant updates when an
#   NLB's underlying nodes change.
# - We set alias.evaluate_target_health to false because Amazon uses these health checks to determine if, in a complex
#   DNS routing tree, it should "back out" of using this DNS Record in favor of another option, and we do not expect
#   such a complex routing tree to be in use here.
resource "aws_route53_record" "fargate_service" {
  zone_id = "${aws_route53_zone.for_testing.id}"
  name    = "service.${var.service_name}"
  type    = "A"

  alias {
    name                   = "${module.nlb.nlb_dns_name}"
    zone_id                = "${module.nlb.nlb_hosted_zone_id}"
    evaluate_target_health = false
  }
}
