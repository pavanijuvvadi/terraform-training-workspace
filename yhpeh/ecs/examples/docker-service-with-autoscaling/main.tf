# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A DOCKER APP WITH AN ELASTIC LOAD BALANCER IN FRONT OF IT
# These templates show an example of how to run a Docker app on top of Amazon's EC2 Container Service (ECS) with an
# Elastic Load Balancer (ELB) routing traffic to the app.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"

  # Only this AWS Account ID may be operated on by this template
  allowed_account_ids = ["${var.aws_account_id}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-cluster?ref=v1.0.8"
  source = "../../modules/ecs-cluster"

  cluster_name = "${var.cluster_name}"

  # Make the max size twice the min size to allow for rolling out updates to the cluster without downtime
  cluster_min_size = 2
  cluster_max_size = 4

  cluster_instance_ami          = "${var.cluster_instance_ami}"
  cluster_instance_type         = "${var.cluster_instance_type}"
  cluster_instance_keypair_name = "${var.cluster_instance_keypair_name}"
  cluster_instance_user_data    = "${data.template_file.user_data.rendered}"

  vpc_id                           = "${var.vpc_id}"
  vpc_subnet_ids                   = ["${var.ecs_cluster_vpc_subnet_ids}"]
  allow_ssh_from_security_group_id = ""
  allow_ssh                        = false
}

# Expose an incoming port for HTTP requests on each instance in the ECS cluster
resource "aws_security_group_rule" "allow_inbound_http_from_elb" {
  type                     = "ingress"
  from_port                = "${var.host_http_port}"
  to_port                  = "${var.host_http_port}"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.ecs_elb.id}"

  security_group_id = "${module.ecs_cluster.ecs_instance_security_group_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = "${file("${path.module}/user-data/user-data.sh")}"

  vars {
    ecs_cluster_name = "${var.cluster_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS TASK TO RUN MY DOCKER CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

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

    cpu    = 512
    memory = 256

    container_http_port = "${var.container_http_port}"
    host_http_port      = "${var.host_http_port}"

    command = "[${join(",", formatlist("\"%s\"", var.container_command))}]"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY TO THE TASK THAT ALLOWS IT TO ACCESS AN S3 BUCKET FOR TESTING PURPOSES
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
  roles      = ["${module.ecs_service.ecs_task_iam_role_name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET FOR TESTING
# We upload a simple text file into this bucket. The ECS Task will try to download the file and display its contents.
# This is used to verify that we are correctly attaching an IAM Policy to the ECS Task that gives it the permissions to
# access the S3 bucket.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "s3_test_bucket" {
  bucket = "${lower(var.service_name)}-test-s3-bucket"
}

resource "aws_s3_bucket_object" "s3_test_file" {
  bucket  = "${aws_s3_bucket.s3_test_bucket.id}"
  key     = "${var.s3_test_file_name}"
  content = "world!"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS SERVICE TO RUN MY ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_service" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-service?ref=v1.0.8"
  source = "../../modules/ecs-service"

  service_name     = "${var.service_name}"
  environment_name = "${var.environment_name}"
  ecs_cluster_arn  = "${module.ecs_cluster.ecs_cluster_arn}"

  ecs_task_container_definitions = "${data.template_file.container_definition.rendered}"
  desired_number_of_tasks        = 2

  # Tell the ECS Service that we are using auto scaling, so the desired_number_of_tasks setting is only used to control
  # the initial number of Tasks, and auto scaling is used to determine the size after that.
  use_auto_scaling = true

  is_associated_with_elb = true
  elb_name               = "${aws_elb.ecs_elb.name}"
  elb_container_name     = "${var.service_name}"
  elb_container_port     = "${var.container_http_port}"

  enable_ecs_deployment_check      = "${var.enable_ecs_deployment_check}"
  deployment_check_timeout_seconds = "${var.deployment_check_timeout_seconds}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELB TO ROUTE TRAFFIC ACROSS THE ECS TASKS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "ecs_elb" {
  name                      = "${var.service_name}"
  security_groups           = ["${aws_security_group.ecs_elb.id}"]
  subnets                   = ["${var.elb_subnet_ids}"]
  cross_zone_load_balancing = true
  connection_draining       = true

  listener {
    instance_port     = "${var.host_http_port}"
    instance_protocol = "http"
    lb_port           = "${var.elb_http_port}"
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:${var.host_http_port}/"
    interval            = 15
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT TRAFFIC CAN GO IN AND OUT OF THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "ecs_elb" {
  name        = "${var.service_name}-elb"
  description = "For the ${var.service_name} ELB."
  vpc_id      = "${var.vpc_id}"

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP inbound from anywhere
  ingress {
    from_port   = "${var.elb_http_port}"
    to_port     = "${var.elb_http_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN APP AUTOSCALING TARGET THAT ALLOWS US TO ADD AUTO SCALING POLICIES TO OUR ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_appautoscaling_target" "appautoscaling_target" {
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  resource_id = "service/${var.cluster_name}/${var.service_name}"
  role_arn    = "${module.ecs_service.service_autoscaling_iam_role_arn}"

  min_capacity = 2
  max_capacity = 5

  depends_on = ["module.ecs_service"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AUTO SCALING POLICIES TO SCALE THE NUMBER OF ECS TASKS UP AND DOWN IN RESPONSE TO LOAD
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_appautoscaling_policy" "scale_out" {
  name        = "${var.service_name}-scale-out"
  resource_id = "service/${var.cluster_name}/${var.service_name}"

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.appautoscaling_target"]
}

resource "aws_appautoscaling_policy" "scale_in" {
  name        = "${var.service_name}-scale-in"
  resource_id = "service/${var.cluster_name}/${var.service_name}"

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.appautoscaling_target"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDWATCH ALARMS TO TRIGGER OUR AUTOSCALING POLICIES BASED ON CPU UTILIZATION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_cpu_usage" {
  alarm_name        = "${var.service_name}-high-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too high"
  namespace         = "AWS/ECS"
  metric_name       = "CPUUtilization"

  dimensions {
    ClusterName = "${var.cluster_name}"
    ServiceName = "${var.service_name}"
  }

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Average"
  threshold           = "90"
  unit                = "Percent"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_out.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_usage" {
  alarm_name        = "${var.service_name}-low-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too low"
  namespace         = "AWS/ECS"
  metric_name       = "CPUUtilization"

  dimensions {
    ClusterName = "${var.cluster_name}"
    ServiceName = "${var.service_name}"
  }

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  unit                = "Percent"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_in.arn}"]
}
