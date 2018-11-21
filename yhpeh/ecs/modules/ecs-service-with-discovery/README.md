# ECS Service with discovery

This Terraform Module creates an [EC2 Container Service (ECS) Service][1] with service discovery.
You can use an ECS service to run one or more related, long-running Docker containers, such as a web service.

Many services are not guaranteed to have the same IP address through their lifespan. They can, for example, be dynamically assigned to run on different hosts, be redeployed after a failure recovery or scale in and out. This makes it complex for services to send traffic to each other.

Service discovery is the action of detecting and addressing these services, allowing them to be found. Some of the ways of doing service discovery are, for example, hardcoding IP addresses, using a Load Balancer or using specialized tools.

ECS *Service Discovery* is an AWS feature allows you to reach your ECS services through a hostname managed by Route53. This hostname will consist of a service discovery name and a namespace (private or public), in the shape of `discovery-name.namespace:port`. For example, on our namespace `sandbox.gruntwork.io`, we can have a service with the discovery name `my-test-webapp` running on port `3000`. This means that we can `dig` or `curl` this service at `my-test-webapp.sandbox.gruntwork.io:3000`. For more information see the [related concepts](#related-concepts) section.

There are many advantages of using ECS Service Discovery instead of reaching it through a Load Balancer, for example:
* Direct communication with the container run by your service
* Lower latency, if using AWS internal network and private namespace
* You can do service-to-service authentication
* Not having a Load Balancer also means fewer resources to manage
* You can configure a Health Check and associate it with all records within a namespace
* You can make a logical group of services under one namespace

**If you wish to deploy instead an ECS Service with an Application Load Balancer (ALB), see the [ecs-service-with-alb module](../ecs-service-with-alb).**

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See [vars.tf](./vars.tf) for all the variables you can set on this module.
* This module assumes you have already deployed:
  * An ECS Cluster: See the [ecs-cluster module](../ecs-cluster) for how to run one.
  * [A service discovery DNS namespace](#route-53-auto-naming-service)
* See the [examples](/examples) folder for example usage.
* This module uses the `ecs-deployment-check` binary available
  under
  [ecs-deploy-check-binaries](../ecs-deploy-check-binaries) to
  have a more robust check for the service deployment. You
  must have `python` installed before you can use this check.
  See the binary [README](../ecs-deploy-check-binaries) for
  more information. You can disable the check by setting the
  module variable `enable_ecs_deployment_check` to `false`.

## How do you add additional IAM policies to the ECS Service?

This module creates an [IAM Role for the ECS Tasks](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
run by the ECS Service. Any custom IAM Policies needed by this ECS Service should be attached to that IAM Role. 

To do this in Terraform, you can use the [aws_iam_role_policy](https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html) or
[aws_iam_policy_attachment](https://www.terraform.io/docs/providers/aws/r/iam_policy_attachment.html) resources, and
set the `role` property to the Terraform output of this module called `ecs_task_iam_role_name`. For example, here is how
you can allow the ECS Service in this cluster to access an S3 bucket:

```hcl
module "ecs_service" {
  # (arguments omitted)
}

resource "aws_iam_role_policy" "access_s3_bucket" {
    name = "access_s3_bucket"
    role = "${module.ecs_service.ecs_task_iam_role_name}"
    policy = "${aws_iam_policy_document.access_s3_bucket.json}"
}

data "aws_iam_policy_document" "access_s3_bucket" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::examplebucket/*"]
  }
}
```

## Gotchas

* The ECS Service Discovery feature is not yet available in all regions.
For a list of regions where this feature is enabled, please see the [AWS ECS Service Discovery documentation][2].
* The discovery name is not necessarily the same as the name of your service. You can have a different name by which you want to discover your service.
* You can enable ECS Service Discovery only during the creation of your ECS service, not when updating it.
* The network mode of the task definition affects the behavior and configuration of ECS Service Discovery DNS Records.
    * Service discovery with `SRV` DNS records are not yet supported by this module. This means that tasks defined with with `host` or `bridge` network modes that can only be used with this type of record are also not supported.
    * For enabling service discovery, this module uses the `awsvpc` network mode. AWS will attach an Elastic Network Interface to your task, so you have to be aware that EC2 instance types have a [limit of how many ENIs can be attached to them][3].
* For service discovery with public DNS: The hostname is public (e.g. your-company.com), but it still points to a private IP address. Querying a public hostname that points to a private IP address might sometimes yield in empty results and you might be required to force reading from a specific nameserver (such as an amazon name server like ns-67.awsdns-08.com or google's public nameserver), for example: `dig +short @8.8.8.8 my-service.my-company.com`

## Related Concepts

### ECS clusters

See the [ecs-cluster module](../ecs-cluster).

### ECS services and tasks

See the [ecs-service module](../ecs-service).

### Route 53 Auto Naming Service

Amazon Route 53 auto naming service automates the process of:
* Creating a public or private namespace within a new or existing hosted zone
* Providing a service with the DNS Records configuration and optional health checks

The latter will be used in the Service Registry of your ECS Service Discovery, and it is the only type of service currently supported for this.

Important considerations:
* Public namespaces are accessible on the internet and need the domain to be registered already
* Private namespaces are accessible only within your VPC and can be queried immediately
* For cleaning up, deregistering the instances from the auto naming service will trigger an automatic deletion of resources in AWS. However, the namespaces themselves are not deleted. Namespaces must be deleted manually and that is only allowed once all services in that namespace no longer exist.

For more information on Route 53 Auto Naming Service, please see the AWS documentation on [Using Auto Naming for Service Discovery][4].

[1]:http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html
[2]:https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-service-discovery.html
[3]:https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html#AvailableIpPerENI
[4]:https://docs.aws.amazon.com/Route53/latest/APIReference/overview-service-discovery.html
