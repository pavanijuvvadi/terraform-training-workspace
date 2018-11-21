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

variable "desired_number_of_tasks" {
  description = "How many copies of the Task to run across the cluster."
}

variable "use_auto_scaling" {
  description = "Set this variable to 'true' to tell the ECS service to ignore var.desired_number_of_tasks and instead use auto scaling to determine how many Tasks of this service to run."
  default     = false
}

variable "deployment_maximum_percent" {
  description = "The upper limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that can be running in a service during a deployment. Setting this to more than 100 means that during deployment, ECS will deploy new instances of a Task before undeploying the old ones."
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The lower limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that must remain running and healthy in a service during a deployment. Setting this to less than 100 means that during deployment, ECS may undeploy old instances of a Task before deploying new ones."
  default     = 100
}

variable "is_associated_with_elb" {
  description = "If set to true, associate this service with the Elasitc Load Balancer (ELB) in var.elb_name."
  default     = false
}

variable "elb_name" {
  description = "The name of an Elastic Load Balancer (ELB) to associate with this service. Containers in the service will automatically register with the ELB when booting up. If var.is_associated_with_elb is false, this value is ignored."
  default     = ""
}

variable "elb_container_name" {
  description = "The name of the container, as it appears in the var.task_arn Task definition, to associate with the ELB in var.elb_name. Currently, ECS can only associate an ELB with a single container per service. If var.is_associated_with_elb is false, this value is ignored."
  default     = ""
}

variable "elb_container_port" {
  description = "The port on the container in var.container_name to associate with the ELB in var.elb_name. Currently, ECS can only associate an ELB with a single container per service. If var.is_associated_with_elb is false, this value is ignored."
  default     = -1
}

variable "ecs_task_definition_canary" {
  description = "The JSON text of the ECS Task Definition to be run for the canary. This defines the Docker container(s) to be run along with all their properties. It should adhere to the format described at https://goo.gl/ob5U3g."
  default     = "[{ \"name\":\"not-used\" }]"
}

variable "desired_number_of_canary_tasks_to_run" {
  description = "How many Tasks to run of the var.canary_task_arn to deploy for a canary deployment. Typically, only 0 or 1 should be used."
  default     = 0
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 1800. Only valid for services configured to use load balancers."
  default     = 0
}

variable "volumes" {
  description = "(Optional) A list of volume blocks that containers in your task may use. Each list item should be a map of name = {volume_name}, host_path = {path on host instance}"
  type        = "list"
  default     = []

  # Example:
  # volumes = [
  #   {
  #     name      = "datadog"
  #     host_path = "/var/run/datadog"
  #   }
  # ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS TASK PLACEMENT PARAMETERS
# These variables are used to determine where ecs tasks should be placed on a cluster.
#
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html#placement_strategy-1
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html#placement_constraints-1
#
# Since placement_strategy and placement_constraint are inline blocks and you can't use count to make them conditional,
# we give some sane defaults here
# ---------------------------------------------------------------------------------------------------------------------
variable "placement_strategy_type" {
  default = "binpack"
}

variable "placement_strategy_field" {
  default = "cpu"
}

variable "placement_constraint_type" {
  default = "memberOf"
}

variable "placement_constraint_expression" {
  default = "attribute:ecs.ami-id != 'ami-fake'"
}

variable "ecs_task_definition_network_mode" {
  description = "The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host"
  default     = "bridge"
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS DEPLOYMENT CHECK OPTIONS
# ---------------------------------------------------------------------------------------------------------------------

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
