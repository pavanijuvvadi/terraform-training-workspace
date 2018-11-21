# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_name" {
  description = "The name of the service. This is used to namespace all resources created by this module."
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "ecs_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the ECS Cluster where this service should run."
}

variable "ecs_task_container_definitions" {
  description = "The JSON text of the ECS Task Container Definitions. This portion of the ECS Task Definition defines the Docker container(s) to be run along with all their properties. It should adhere to the format described at https://goo.gl/ob5U3g."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "ecs_task_definition_network_mode" {
  description = "The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host"
  default     = "bridge"
}

variable "volumes" {
  description = "(Optional) A set of volume blocks that containers in your task may use."
  default     = []
}

# Deployment Check Options

variable "enable_ecs_deployment_check" {
  description = "Whether or not to enable the ECS deployment check binary to make terraform wait for the task to be deployed. See ecs_deploy_check_binaries for more details. You must install the companion binary before the check can be used. Refer to the README for more details."
  default     = true
}

variable "deployment_check_timeout_seconds" {
  description = "Seconds to wait before timing out each check for verifying ECS service deployment. See ecs_deploy_check_binaries for more details."
  default     = 600
}

variable "deployment_check_loglevel" {
  description = "Set the logging level of the deployment check script. You can set this to `error`, `warn`, or `info`, in increasing verbosity."
  default     = "info"
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS TASK PLACEMENT PARAMETERS
# These variables are used to determine where ecs tasks should be placed on a cluster.
#
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html#placement_constraints-1
#
# Since placement_constraint is an inline block and you can't use count to make it conditional,
# we give some sane defaults here
# ---------------------------------------------------------------------------------------------------------------------
variable "placement_constraint_type" {
  default = "memberOf"
}

variable "placement_constraint_expression" {
  default = "attribute:ecs.ami-id != 'ami-fake'"
}
