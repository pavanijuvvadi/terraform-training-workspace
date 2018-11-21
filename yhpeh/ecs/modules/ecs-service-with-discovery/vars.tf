# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module.
# ---------------------------------------------------------------------------------------------------------------------
variable "service_name" {
  description = "The name of the service. This is used to namespace all resources created by this module."
}

variable "environment_name" {
  description = "The environment name in which the ECS Service is located. (e.g. stage, prod)"
}

variable "ecs_cluster_name" {
  description = "The name of the ECS Cluster where this ECS Service will be created."
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

variable "vpc_id" {
  description = "The ID of VPC that you want to associate the namespace with."
}

variable "subnet_ids" {
  description = "Subnet ids for the network configuration. Required for tasks with awsvpc network mode."
  type        = "list"
}

variable "discovery_namespace_id" {
  description = "The id of the previously created namespace for service discovery. It will be used to form the service discovery address along with the discovery name in <discovery_name>.<namespace_name>. So if your discovery name is 'my-service' and your namespace name is 'my-company-staging.local', the hostname for the service will be 'my-service.my-company-staging.local'."
}

variable "discovery_name" {
  description = "The name by which the service can be discovered. It will be used to form the service discovery address along with the namespa name in <discovery_name>.<namespace_name>. So if your discovery name is 'my-service' and your namespace name is 'my-company-staging.local', the hostname for the service will be 'my-service.my-company-staging.local'."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------
variable "use_public_dns" {
  description = "Use a public DNS hostname for service discovery"
  default     = false
}

variable "original_public_route53_zone_id" {
  description = "Hosted zone id of original public DNS. Only necessary if using public DNS"
  default     = ""
}

variable "new_route53_zone_id" {
  description = "Hosted zone id of service discovery namespace. Only necessary if using public DNS"
  default     = ""
}

variable "discovery_namespace_name" {
  description = "DNS hostname used for namespacing your service. Only necessary if using public DNS"
  default     = ""
}

variable "alias_record_evaluate_target_health" {
  description = "Check alias target health before routing to the service. Optional. Only used if using public DNS"
  default     = true
}

variable "allow_inbound_from_cidr_blocks" {
  description = "The list of CIDR blocks for your task network to allow inbound connections from"
  type        = "list"
  default     = []
}

variable "num_allow_inbound_security_groups" {
  description = "The number of security groups that are allowed to send traffic to the task network"
  default     = 0
}

variable "allow_inbound_from_security_group_ids" {
  description = "The list of security group ids that are allowed to send traffic to the task network"
  type        = "list"
  default     = []
}

variable "custom_ecs_task_security_group_ids" {
  description = "The list of security group ids to additionally associate with the ECS task network."
  type        = "list"
  default     = []
}

variable "discovery_custom_health_check_failure_threshold" {
  description = "The number of 30-second intervals that you want service discovery to wait before it changes the health status of a service instance. Maximum value of 10"
  default     = 1
}

variable "discovery_dns_ttl" {
  description = "The amount of time, in seconds, that you want DNS resolvers to cache the settings for this resource record set."
  default     = 60
}

variable "discovery_dns_routing_policy" {
  description = " The routing policy that you want to apply to all records that Route 53 creates when you register an instance and specify the service. Valid Values: MULTIVALUE, WEIGHTED"
  default     = "MULTIVALUE"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 1800. Only valid for services configured to use load balancers."
  default     = 0
}

variable "container_http_port" {
  description = "The port var.docker_image listens on for HTTP requests"
}

# Auto Scaling Options

variable "use_auto_scaling" {
  description = "Set this variable to 'true' to tell the ECS service to ignore var.desired_number_of_tasks and instead use Auto Scaling to determine how many ECS Tasks of this service to run."
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

variable "min_number_of_tasks" {
  description = "The minimum number of ECS Task instances of the ECS Service to run. Auto scaling will never scale in below this number."
  default     = 1
}

variable "max_number_of_tasks" {
  description = "The maximum number of ECS Task instances of the ECS Service to run. Auto scaling will never scale out above this number."
  default     = 1
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
