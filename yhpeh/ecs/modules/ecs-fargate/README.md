# Fargate Module

This Terraform Module creates a [Fargate Service](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html) that you can use to run one or more related, long-running Docker containers, such as a web service. A Fargate ECS service automatically manages and scales your cluster as needed without you needing to manage the underlying EC2 instances or clusters. Fargate lets you focus on designing and building your applications instead of managing the infrastructure that runs them, with Fargate, all you have to do is package your application in containers, specify the CPU and memory requirements, define networking and IAM policies, and launch the application.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See the [examples](/examples) folder for example usage.
* See [vars.tf](./vars.tf) for all the variables you can set on this module.
* This module uses the `ecs-deployment-check` binary available
  under
  [ecs-deploy-check-binaries](../ecs-deploy-check-binaries) to
  have a more robust check for the service deployment. You
  must have `python` installed before you can use this check.
  See the binary [README](../ecs-deploy-check-binaries) for
  more information. You can disable the check by setting the
  module variable `enable_ecs_deployment_check` to `false`.


## What is Fargate?

Under the hood, Fargate is basically an ECS Service with the `FARGATE` launch type and is as a result API compatible with ECS. To run Docker containers with Fargate, you first define an [ECS Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_defintions.html), which is a JSON file that describes what containers to run, the resources (memory, CPU) those containers need, the volumes to mount, the environment variables to set, and so on. To actually run an ECS Task, you define a Fargate Service, which can:

1. Deploy the requested number of Tasks on Fargate based on the `desired_number_of_tasks` input variable.
1. Restart tasks if they fail.
1. Route traffic across the tasks with an optional Load Balancer (ALB or NLB). To use a load balancer, set `is_associated_with_lb` to `true` and pass in the details using the `load_balancer_arn`, `container_name` and `container_port` input variables.
1. Ensure that `httpPort` in the container definitions json file is _explicitly_ set to the same value as `containerPort` so that `terraform apply` doesn't try to apply a change when there's none.
1. Pull public images from the docker registry, you must set `assign_public_ip` to `true`


## How do Fargate Services deploy new versions of containers?

When you update an ECS Task (e.g. change the version number of a Docker container to deploy), Fargate will roll the change out automatically across your cluster according to two input variables:

* `deployment_maximum_percent`: This variable controls the maximum number of copies of your ECS Task, as a percentage of `desired_number_of_tasks`, that can be deployed during an update. For example, if you have 4 Tasks running at version 1, `deployment_maximum_percent` is set to 200, and you kick off a deployment of version 2 of your Task, Fargate will first deploy 4 Tasks at version 2, wait for them to come up, and then it'll undeploy the 4 Tasks at version 1. Fargate automatically handles all the underlying infrastructure changes needed to make this possible, adding and removing EC2 instances as needed.

* `deployment_minimum_healthy_percent`: This variable controls the minimum number of copies of your ECS Task, as a percentage of `desired_number_of_tasks`, must stay running during an update. For example if you have 4 Tasks running at version 1, you set `deployment_minimum_healthy_percent` to 50, and you kick off a deployment of version 2 of your Task, Fargate will first undeploy 2 Tasks at version 1, then deploy 2 Tasks at version 2 in their place, and then repeat the process again with the remaining 2 tasks. This allows you to roll out new versions without having to keep spare EC2 instances, but it also means the availability of your service is somewhat reduced during rollouts.

## How do you add additional IAM policies?

If you associate this Fargate Service with an ELB (`is_associated_with_elb` is set to true), then we create an IAM Role and associated IAM Policies that allow the ECS Service to talk to the ELB. To add additional IAM policies to this IAM Role, you can use the [aws_iam_role_policy](https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html) or [aws_iam_policy_attachment](https://www.terraform.io/docs/providers/aws/r/iam_policy_attachment.html) resources, and set the IAM role id to the Terraform output of this module called `service_iam_role_id` . For example, here is how you can allow the Fargate Service in this cluster to access an S3 bucket:

```hcl
module "fargate_service" {
  # (arguments omitted)
}

resource "aws_iam_role_policy" "access_s3_bucket" {
    name = "access_s3_bucket"
    role = "${module.ecs_service.service_iam_role_arn}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect":"Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::examplebucket/*"
    }
  ]
}
EOF
}
```
