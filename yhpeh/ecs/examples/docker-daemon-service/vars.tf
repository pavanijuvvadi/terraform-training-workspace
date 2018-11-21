# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# TF_VAR_api_key

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_account_id" {
  description = "A comma-separated list of AWS Account IDs. Only these IDs may be operated on by this template."
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created."
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "cpu" {
  description = "The amount of cpu units to give the container."
}

variable "memory" {
  description = "The amount of memory units to give the container."
}

variable "api_key" {
  description = "The datadog api key."
}

variable "ecs_cluster_arn" {
  description = "The arn of the cluster to launch the daemon service in."
}

variable "service_name" {
  description = "The name of the service. This is used to namespace all resources created by this module."
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
