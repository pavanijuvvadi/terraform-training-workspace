# Exercise 04c

1. Update your ASG to support zero-downtime deployments
1. Change User Data and run `apply` to see a deployment
1. Submit a PR



## Hint: launch configuration name

You should omit the `name` parameter from the launch configuration. Launch configuration names must be unique, and 
since Terraform is creating a new one each time, it needs a unique name each time. When you omit the `name` parameter,
Terraform will auto-generate a unique name for you.




## Hint: depends_on

Since the ASG now uses the ALB health checks, we need to make sure the ALB is fully operational *before* deploying the
ASG. To do that, you need to add an [explicit 
dependency](https://www.terraform.io/intro/getting-started/dependencies.html#implicit-and-explicit-dependencies) from 
the ASG to your ALB listener(s):

```hcl
depends_on = ["aws_alb_listener.http"]
```