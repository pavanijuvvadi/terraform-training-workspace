variable "instance_http_port" {
  description = "The port the EC2 Instance will listen on for HTTP requests"
  default = 8080
}

variable "elb_http_port" {
  description = "The port the ELB will listen on for HTTP requests"
  default     = 80
}

variable "name" {
  description = "Used to namespace all the resources"
}

variable "num_servers" {
  description = "How many EC2 Instances to run in the Auto Scaling Group"
  default = 3
}

variable "enable_route53_health_check" {
  description = "If set to true, enable the Route 53 health check"
}