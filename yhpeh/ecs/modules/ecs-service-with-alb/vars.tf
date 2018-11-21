# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_account_id" {
  description = "The AWS Account ID in which the ECS Service will be created."
}

variable "aws_region" {
  description = "The AWS region in which the ECS Service will be created."
}

variable "service_name" {
  description = "The name of the service. This is used to namespace all resources created by this module."
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "vpc_id" {
  description = "The ID of the VPC in which the ECS Service container instances will be located."
}

variable "ecs_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the ECS Cluster where this ECS Service should be created."
}

variable "ecs_cluster_name" {
  description = "The name of the ECS Cluster where this ECS Service will be created."
}

variable "ecs_task_container_definitions" {
  description = "The JSON text of the ECS Task Container Definitions. This portion of the ECS Task Definition defines the Docker container(s) to be run along with all their properties. It should adhere to the format described at https://goo.gl/ob5U3g."
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

variable "desired_number_of_tasks" {
  description = "How many instances of the ECS Task to run across the cluster. If using Auto Scaling, this property will be ignored after the initial Terraform apply."
}

variable "min_number_of_tasks" {
  description = "The minimum number of ECS Task instances of the ECS Service to run. Auto scaling will never scale in below this number."
}

variable "max_number_of_tasks" {
  description = "The maximum number of ECS Task instances of the ECS Service to run. Auto scaling will never scale out above this number."
}

variable "alb_arn" {
  description = "The Amazon Resource Name (ARN) of the ALB that this ECS Service will use as its load balancer."
}

variable "alb_container_name" {
  description = "The name of the container, as it appears in the var.task_arn ECS Task Definition, to associate with the ALB in var.alb_name. Currently, ECS can only associate an ALB with a single container per service. The significance of a container being associated with an ALB relates to Health Checks and which container is routed traffic from the ALB."
  default     = ""
}

variable "alb_container_port" {
  description = "The port on the container in var.alb_container_name to associate with the ALB. Currently, ECS can only associate an ALB with a single container per ECS Task. For example, if an ECS Task defines three separate containers, the ALB can only be associated with one of them. The significance of a container being associated with an ALB is that the ALB will route traffic to this container only (not other containers in the ECS Task), and will direct Health Checks to this container only."
  default     = -1
}

variable "alb_target_group_name" {
  description = "The name of the ALB Target Group that will contain the ECS Tasks. Setting this value to the empty string will default to the name 'var.service_name'."
  default     = ""
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------
variable "ecs_task_definition_network_mode" {
  description = "The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host"
  default     = "bridge"
}

# ALB Target Group Defaults

variable "alb_target_group_protocol" {
  description = "The network protocol to use for routing traffic from the ALB to the Targets. Must be one of HTTP or HTTPS. Note that if HTTPS is used, per https://goo.gl/NiOVx7, the ALB will use the security settings from ELBSecurityPolicy2015-05."
  default     = "HTTP"
}

variable "alb_target_group_deregistration_delay" {
  description = "The amount of time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds."
  default     = 300
}

# Auto Scaling Options

variable "use_auto_scaling" {
  description = "Set this variable to 'true' to tell the ECS service to ignore var.desired_number_of_tasks and instead use Auto Scaling to determine how many ECS Tasks of this service to run."
  default     = false
}

variable "deployment_maximum_percent" {
  description = "The upper limit, as a percentage of var.desired_number_of_tasks, of the number of running ECS Tasks that can be running in a service during a deployment. Setting this to more than 100 means that during deployment, ECS will deploy new instances of a Task before undeploying the old ones."
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The lower limit, as a percentage of var.desired_number_of_tasks, of the number of running ECS Tasks that must remain running and healthy in a service during a deployment. Setting this to less than 100 means that during deployment, ECS may undeploy old instances of a Task before deploying new ones."
  default     = 100
}

# Canary Options

variable "desired_number_of_canary_tasks_to_run" {
  description = "How many ECS Tasks to run of the var.ecs_task_definition_canary to deploy for a canary deployment. Typically, only 0 or 1 should be used."
  default     = 0
}

variable "ecs_task_definition_canary" {
  description = "The JSON text of the ECS Task Definition to be run for the canary. This defines the Docker container(s) to be run along with all their properties. It should adhere to the format described at https://goo.gl/ob5U3g."
  default     = "[{ \"name\":\"not-used\" }]"
}

# Sticky Session Options

variable "use_alb_sticky_sessions" {
  description = "If true, the ALB will use use Sticky Sessions as described at https://goo.gl/VLcNbk."
  default     = false
}

variable "alb_sticky_session_type" {
  description = "The type of Sticky Sessions to use. See https://goo.gl/MNwqNu for possible values."
  default     = "lb_cookie"
}

variable "alb_sticky_session_cookie_duration" {
  description = "The time period, in seconds, during which requests from a client should be routed to the same Target. After this time period expires, the load balancer-generated cookie is considered stale. The acceptable range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds)."
  default     = 86400
}

# Health Check Defaults

variable "health_check_interval" {
  description = "The approximate amount of time, in seconds, between health checks of an individual Target. Minimum value 5 seconds, Maximum value 300 seconds."
  default     = 30
}

variable "health_check_path" {
  description = "The ping path that is the destination on the Targets for health checks."
  default     = "/"
}

variable "health_check_port" {
  description = "The port the ALB uses when performing health checks on Targets. The default is to use the port on which each target receives traffic from the load balancer, indicated by the value 'traffic-port'."
  default     = "traffic-port"
}

variable "health_check_protocol" {
  description = "The protocol the ALB uses when performing health checks on Targets. Must be one of HTTP and HTTPS."
  default     = "HTTP"
}

variable "health_check_timeout" {
  description = "The amount of time, in seconds, during which no response from a Target means a failed health check. The acceptable range is 2 to 60 seconds."
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successful health checks required before considering an unhealthy Target healthy. The acceptable range is 2 to 10."
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failed health checks required before considering a target unhealthy. The acceptable range is 2 to 10."
  default     = 2
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from a Target. You can specify multiple values (e.g. '200,202') or a range of values (e.g. '200-299')."
  default     = "200"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 1800. Only valid for services configured to use load balancers."
  default     = 0
}

# ECS Deployment Check Options

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
