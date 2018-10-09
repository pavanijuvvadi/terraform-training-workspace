# Exercise 05a

1. Move the ASG/ALB code into a "microservice" module
1. Lock down the server security groups
1. Make the ALB optionally internal
1. Use the module to deploy a microservice
1. Submit a PR




## Hint: security groups

A nice way to lock down security groups is to only allow requests from certain other security groups (see the 
`source_security_group_id` parameter). A common use case for this is to lock down EC2 Instances to only accept HTTP
requests from the security group of the ALB.
