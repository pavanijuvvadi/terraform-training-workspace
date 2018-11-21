# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
}

variable "service_name" {
  description = "The name of the ECS service"
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "ecs_cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster"
}

variable "discovery_namespace_name" {
  description = "The host name for the service discovery namespace. Example: my-company-staging.local"
}

variable "vpc_id" {
  description = "The AWS ID of the VPC to use for the application container."
}

variable "private_subnet_ids" {
  description = "List of AWS IDs of the private subnets in VPC to use for the application container."
  type        = "list"
}

variable "public_subnet_ids" {
  description = "List of AWS IDs of the public subnets in VPC to use for the ssh container."
  type        = "list"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "ecs_cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
  default     = ""
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
