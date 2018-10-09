# Exercise 03

1. Update exercise-01 to deploy 3 EC2 Instances, each with a different Name tag
1. Output the public IPs of the Instances
1. Submit a PR




## Hint: interpolation functions

You'll need to use Terraform's [interpolation functions](https://www.terraform.io/docs/configuration/interpolation.html)
in this exercise. Make sure to browse that page, as there's lots of useful info there!




## Hint: count and lists
 
Once you add the `count` parameter to a resource, it's no longer one resource, but a list of resources. You'll need 
to take that into account when referencing an output attribute of that resource.

For example, if you set the `count` parameter to `3` on an `aws_instance` resource called `foo`, then to get the IDs
of all of the EC2 Instances, you could use the splat syntax: `aws_instance.foo.*.id`.