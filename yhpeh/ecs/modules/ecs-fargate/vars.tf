# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module.
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  description = "The ID of the VPC into which the Fargate task will deploy."
}

variable "subnet_ids" {
  description = "A list of the subnets into which the Fargate tasks will be launched. These should usually be all private subnets and include one in each AWS Availability Zone."
  type        = "list"
}

variable "service_name" {
  description = "The name of the service. This is used to namespace all resources created by this module."
}

variable "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster to deploy the Fargate service to."
}

variable "container_definitions" {
  description = "The JSON text of the Fargate Task Container Definitions. This portion of the ECS Task Definition defines the Docker container(s) to be run along with all their properties. It should adhere to the format described at https://goo.gl/ob5U3g."
}

variable "cpu" {
  description = "The CPU units for the instances that Fargate will spin up. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size."
}

variable "memory" {
  description = "The memory units for the instances that Fargate will spin up. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size."
}

variable "desired_number_of_tasks" {
  description = "How many copies of the Task to run."
}

variable "allow_inbound_from_cidr_blocks" {
  description = "The list of CIDR blocks for your Fargate service to allow inbound connections from"
  type        = "list"
}

variable "allow_inbound_from_security_group_ids" {
  description = "The list of security group ids that are allowed to send traffic to the Fargate service"
  type        = "list"
}

variable "protocol" {
  description = "The protocol for your Fargate service to allow inbound connections on. You can specify more protocols by adding an addtional scurity group rule and attaching it to the 'fargate_instance_security_group_id' output"
}

variable "from_port" {
  description = "The start port for your Fargate service to allow inbound connections on. You can specify more port ranges by adding an addtional scurity group rule and attaching it to the 'fargate_instance_security_group_id' output"
}

variable "to_port" {
  description = "The end port for your Fargate service to allow inbound connections on. You can specify more port ranges by adding an addtional scurity group rule and attaching it to the 'fargate_instance_security_group_id' output"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "assign_public_ip" {
  description = "Assign a public IP address to the ENI (Fargate launch type only). Valid values are true or false. Default false. This must be set to true to enable your Fargate task pull images from the docker registry"
  default     = false
}

variable "is_associated_with_lb" {
  description = "If set to true, associate this service with a Load Balancer (LB)."
  default     = false
}

variable "lb_container_name" {
  description = "The name of the container, as it appears in the var.task_arn ECS Task Definition, to associate with the Load Balancer."
  default     = ""
}

variable "lb_container_port" {
  description = "The port on the container in var.lb_container_name to associate with the Load Balancer"
  default     = -1
}

variable "load_balancer_arn" {
  description = "The Amazon Resource Name (ARN) of the ALB or NLB that this Fargate Service will use as its load balancer."
  default     = ""
}

variable "lb_target_group_deregistration_delay" {
  description = "The amount of time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds."
  default     = 300
}

# ALB Target Group Defaults

variable "alb_target_group_protocol" {
  description = "The network protocol to use for routing traffic from the ALB to the Targets. Must be one of HTTP or HTTPS. Note that if HTTPS is used, per https://goo.gl/NiOVx7, the ALB will use the security settings from ELBSecurityPolicy2015-05."
  default     = "HTTP"
}

# Fargate Service Defaults

variable "deployment_maximum_percent" {
  description = "The upper limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that can be running in a service during a deployment. Setting this to more than 100 means that during deployment, ECS will deploy new instances of a Task before undeploying the old ones."
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The lower limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that must remain running and healthy in a service during a deployment. Setting this to less than 100 means that during deployment, ECS may undeploy old instances of a Task before deploying new ones."
  default     = 100
}

variable "custom_tags_security_group" {
  description = "A map of custom tags to apply to the Security Group for the Fargate service. The key is the tag name and the value is the tag value."
  type        = "map"
  default     = {}

  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
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
