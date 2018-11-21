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
  default     = "us-east-1"
}

variable "service_name" {
  description = "The name of the ECS service to run"
  default     = "fargate-no-lb"
}

variable "http_port" {
  description = "The port on which the host and container listens on for HTTP requests"
  default     = 3000
}

variable "desired_number_of_tasks" {
  description = "How many instances of the container to schedule on the cluster"
  default     = 3
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
  description = "Command to run on the container. Set this to see what happens when a container is set up to exit on boot"
  type        = "list"
  default     = []

  # Example:
  # default = ["echo", "Hello"]
}
