# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

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

variable "ecs_cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster"
}

variable "docker_image" {
  description = "The Docker image to run in the ECS Task (e.g. acme/my-container)"
}

variable "docker_image_version" {
  description = "The version of the Docker image in var.docker_image to run in the ECS Task (e.g. latest)"
}

variable "docker_image_command" {
  description = "The command to run in the Docker image."
  type        = "list"

  # Example:
  # default = ["echo", "Hello"]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "ecs_cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
  default     = ""
}
