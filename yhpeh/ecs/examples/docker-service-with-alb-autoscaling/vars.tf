# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
}

variable "aws_account_id" {
  description = "A comma-separated list of AWS Account IDs. Only these IDs may be operated on by this template."
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
}

variable "ecs_cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster"
}

variable "ecs_cluster_instance_type" {
  description = "The type of instances to run in the ECS cluster (e.g. t2.micro)"
  default     = "t2.micro"
}

variable "ecs_cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
}

variable "ecs_cluster_vpc_subnet_ids" {
  description = "A list of subnet ids in which the ECS cluster should be deployed. If using the standard Gruntwork VPC, these should typically be the private app subnet ids."
  type        = "list"
}

variable "vpc_id" {
  description = "The id of the VPC in which to run the ECS cluster"
}

variable "vpc_cidr_block" {
  description = "The CIDR-formatted IP Address range of the VPC. (e.g. 10.0.0.0/24)"
}

variable "container_name" {
  description = "The name of the container in the ECS Task Definition. This is only useful if you have multiple containers defined in the ECS Task Definition. Otherwise, it doesn't matter."
  default     = "webapp"
}

variable "service_name" {
  description = "The name of the ECS service to run"
  default     = "example-ecs-service-with-elb"
}

variable "environment_name" {
  description = "The environment name in which the ALB is located. (e.g. prod)"
}

variable "container_http_port" {
  description = "The port var.docker_image listens on for HTTP requests"

  # The Docker container we run in this example listens on port 3000
  default = 3000
}

variable "server_text" {
  description = "The Docker container we run in this example will display this text for every request."
  default     = "Hello"
}

variable "s3_test_file_name" {
  description = "The name of the file to store in the S3 bucket. The ECS Task will try to download this file from S3 as a way to check that we are giving the Task the proper IAM permissions."
  default     = "s3-test-file.txt"
}

variable "alb_vpc_subnet_ids" {
  description = "A list of the subnets into which the ALB will place its underlying nodes. Include one subnet per Availabability Zone. If the ALB is public-facing, these should be public subnets. Otherwise, they should be private subnets."
  type        = "list"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables have defaults and may be overwritten
# ---------------------------------------------------------------------------------------------------------------------

variable "route53_hosted_zone_name" {
  description = "The name of the Route53 Hosted Zone where we will create a DNS record for this service (e.g. gruntwork-dev.io)"
  default     = "gruntwork-dev.io"
}

variable "enable_ecs_deployment_check" {
  description = "Whether or not to enable ECS deployment check. This requires installation of the check-ecs-service-deployment binary. See the ecs-deploy-check-binaries module README for more information."
  default     = false
}

variable "deployment_check_timeout_seconds" {
  description = "Number of seconds to wait for the ECS deployment check before giving up as a failure."
  default     = 600
}

variable "container_command" {
  description = "Command to run on the container. Set this to see what happens when a container is set up to exit on boot."
  type        = "list"
  default     = []

  # Example:
  # default = ["echo", "Hello"]
}
