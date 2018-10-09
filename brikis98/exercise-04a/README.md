# Exercise 04a

1. Create an ASG to run three web servers
1. Submit a PR




## Hint: create_before_destroy

When using an [aws_autoscaling_group resource](https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html) 
with an [aws_launch_configuration resource](https://www.terraform.io/docs/providers/aws/r/launch_configuration.html), 
you must set `create_before_destroy = true` on the `aws_launch_configuration`:

```hcl
resource "aws_launch_configuration" "example" {
  # (other params omitted)

  lifecycle {
    create_before_destroy = true
  }
}
```

Once you've set `create_before_destroy` to `true` on resource `X`, you must *also* go through every resource `Y` that 
`X` depends on and set `create_before_destroy` to `true` for them too. And then you have to go through every resource
`Y` depends on and do the same thing, all the way down the line.




## Hint: subnets and availability zones

You will have to tell the ASG which subnets and/or availability zones it can deploy into. In real-world usage, you'd 
have a custom VPC and subnets, but to keep this exercise simple, you can use the 
[aws_vpc](https://www.terraform.io/docs/providers/aws/d/vpc.html) and 
[aws_subnet_ids](https://www.terraform.io/docs/providers/aws/d/subnet_ids.html) data sources to fetch the list of 
default subnets for your Default VPC:

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}
```

You can then pass the list of subnets to the ASG using the `` parameter:

```hcl
vpc_zone_identifier = ["${data.aws_subnet_ids.default.ids}"]
```