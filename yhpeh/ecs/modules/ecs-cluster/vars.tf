# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module.
# ---------------------------------------------------------------------------------------------------------------------

# General ECS Cluster properties
variable "cluster_name" {
  description = "The name of the ECS cluster (e.g. ecs-prod). This is used to namespace all the resources created by these templates."
}

variable "cluster_min_size" {
  description = "The minimum number of EC2 Instances launchable for this ECS Cluster. Useful for auto-scaling limits."
}

variable "cluster_max_size" {
  description = "The maximum number of EC2 Instances that must be running for this ECS Cluster. We recommend making this twice var.cluster_min_size, even if you don't plan on scaling the cluster up and down, as the extra capacity will be used to deploy udpates to the cluster."
}

# Properties of the ECS Cluster's EC2 Instances
variable "cluster_instance_ami" {
  description = "The AMI to run on each of the ECS Cluster's EC2 Instances."
}

variable "cluster_instance_type" {
  description = "The type of EC2 instance to run for each of the ECS Cluster's EC2 Instances (e.g. t2.medium)."
}

variable "cluster_instance_root_volume_size" {
  description = "The size in GB of the root volume for each of the ECH Cluster's EC2 Instances"
  default     = 40
}

variable "cluster_instance_root_volume_type" {
  description = "The volume type for the root volume for each of the ECH Cluster's EC2 Instances. Can be standard, gp, or io1"
  default     = "standard"
}

variable "cluster_instance_keypair_name" {
  description = "The EC2 Keypair name used to SSH into the ECS Cluster's EC2 Instances."
}

variable "cluster_instance_user_data" {
  description = "The User Data script to run on each of the ECS Cluster's EC2 Instances on their first boot."
}

variable "cluster_instance_spot_price" {
  description = "If set to a non-empty string EC2 Spot Instances will be requested for the ECS Cluster. The value is the maximum bid price for the instance on the EC2 Spot Market."
  default     = ""
}

# Info about the VPC in which this Cluster resides

variable "vpc_id" {
  description = "The ID of the VPC in which the ECS Cluster's EC2 Instances will reside."
}

variable "vpc_subnet_ids" {
  description = "A list of the subnets into which the ECS Cluster's EC2 Instances will be launched. These should usually be all private subnets and include one in each AWS Availability Zone."
  type        = "list"
}

variable "allow_ssh_from_security_group_id" {
  description = "The security group id from which SSH access should be permitted to the ECS Cluster instances. Should typically be the security group id of a bastion host."
}

variable "allow_ssh" {
  description = "Set to true if var.allow_ssh_from_security_group_id is non-empty; false, otherwise. Due to a terraform bug (https://github.com/hashicorp/terraform/issues/3888), we can't use the value of var.allow_ssh_from_security_group_id as part of a 'count' property to dynamically decide to create a resource. So we settle for this redundant var."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "alb_security_group_ids" {
  description = "A list of Security Group IDs of the ALBs which will send traffic to this ECS Cluster."
  type        = "list"
  default     = []
}

variable "num_alb_security_group_ids" {
  description = "The number of entries in var.alb_arns. We should be able to infer this value from var.alb_arns, but due to a Terraform Bug (https://goo.gl/gq5Qyk), we must set it manually."
  default     = 0
}

variable "tenancy" {
  description = "The tenancy of the servers in this cluster. Must be one of: default, dedicated, or host."
  default     = "default"
}

variable "custom_tags_ec2_instances" {
  description = "A list of custom tags to apply to the EC2 Instances in this ASG. Each item in this list should be a map with the parameters key, value, and propagate_at_launch."
  type        = "list"
  default     = []

  # Example:
  # default = [
  #   {
  #     key = "foo"
  #     value = "bar"
  #     propagate_at_launch = true
  #   },
  #   {
  #     key = "baz"
  #     value = "blah"
  #     propagate_at_launch = true
  #   }
  # ]
}

variable "custom_tags_security_group" {
  description = "A map of custom tags to apply to the Security Group for this ECS Cluster. The key is the tag name and the value is the tag value."
  type        = "map"
  default     = {}

  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
}
