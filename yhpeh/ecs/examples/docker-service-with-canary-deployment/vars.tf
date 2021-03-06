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

variable "cluster_name" {
  description = "The name of the ECS cluster"
  default     = "example-doker-service-with-canary"
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster"
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the ECS cluster (e.g. t2.micro)"
  default     = "t2.micro"
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
}

variable "vpc_id" {
  description = "The id of the VPC in which to run the ECS cluster"
}

variable "ecs_cluster_vpc_subnet_ids" {
  description = "A list of subnet ids in which the ECS cluster should be deployed. If using the standard Gruntwork VPC, these should typically be the private app subnet ids."
  type        = "list"
}

variable "elb_subnet_ids" {
  description = "A list of subnet ids where the ELB should be deployed. If using the standard Gruntwork VPC, these should typically be the public app subnet ids."
  type        = "list"
}

variable "service_name" {
  description = "The name of the ECS service to run"
  default     = "example-ecs-service-with-elb"
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "container_http_port" {
  description = "The port var.docker_image listens on for HTTP requests"

  # The Docker container we run in this example listens on port 3000
  default = 3000
}

variable "host_http_port" {
  description = "The port each instance in the ECS cluster exposes for HTTP requests"
  default     = 8080
}

variable "elb_http_port" {
  description = "The port the ELB listens on for HTTP requests"
  default     = 80
}

variable "server_text" {
  description = "The Docker container we run in this example will display this text for every request."
  default     = "Hello"
}

variable "s3_test_file_name" {
  description = "The name of the file to store in the S3 bucket. The ECS Task will try to download this file from S3 as a way to check that we are giving the Task the proper IAM permissions."
  default     = "s3-test-file.txt"
}

variable "canary_server_text" {
  description = "The Docker container we run during a canary deployment will display this text for every request."
  default     = "Hello Canary"
}

variable "desired_number_of_canary_tasks_to_run" {
  description = "How many Tasks to run to do a canary deployment of a new version of the sample Docker app. Typically, only 0 or 1 should be used."
  default     = 0
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

variable "canary_container_command" {
  description = "Command to run on the canary_container. Set this to see what happens when a container is set up to exit on boot."
  type        = "list"
  default     = []

  # Example:
  # default = ["echo", "Hello"]
}
