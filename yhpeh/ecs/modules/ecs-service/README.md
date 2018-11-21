# ECS Service Module

This Terraform Module creates an [EC2 Container Service
Service](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html) that you can use to run one or
more related, long-running Docker containers, such as a web service. An ECS service can automatically deploy multiple
instances of your Docker containers across an ECS cluster (see the [ecs-cluster module](../ecs-cluster)), restart any
failed Docker containers, and route traffic across your containers using an optional Elastic Load Balancer (ELB). This
module also supports [canary deployment](http://martinfowler.com/bliki/CanaryRelease.html), where you can deploy a
single instance of a new Docker container version, test it, and if everything works well, deploy that version across
the rest of the cluster.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See the [examples](/examples) folder for example usage.
* See [vars.tf](./vars.tf) for all the variables you can set on this module.
* See the [ecs-cluster module](../ecs-cluster) for how to run an ECS cluster.
* This module uses the `ecs-deployment-check` binary available
  under
  [ecs-deploy-check-binaries](../ecs-deploy-check-binaries) to
  have a more robust check for the service deployment. You
  must have `python` installed before you can use this check.
  See the binary [README](../ecs-deploy-check-binaries) for
  more information. You can disable the check by setting the
  module variable `enable_ecs_deployment_check` to `false`.


## What is an ECS Service?

To run Docker containers with ECS, you first define an [ECS
Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_defintions.html), which is a JSON file that
describes what container(s) to run, the resources (memory, CPU) those containers need, the volumes to mount, the
environment variables to set, and so on. To actually run an ECS Task, you define an ECS Service, which can:

1. Deploy the requested number of Tasks across an ECS cluster based on the `desired_number_of_tasks` input variable.
1. Restart tasks if they fail.
1. Route traffic across the tasks with an optional Elastic Load Balancer (ELB). To use an ELB, set `is_associated_with_elb`
   to `true` and pass in the ELB details using the `load_balancer_name`, `container_name`, and `container_port`
   input variables.

## How do you create an ECS cluster?

To use ECS, you first deploy one or more EC2 Instances into a "cluster". See the [ecs-cluster module](../ecs-cluster)
for how to create a cluster.

## How do ECS Services deploy new versions of containers?

When you update an ECS Task (e.g. change the version number of a Docker container to deploy), ECS will roll the change
out automatically across your cluster according to two input variables:

* `deployment_maximum_percent`: This variable controls the maximum number of copies of your ECS Task, as a percentage of
  `desired_number_of_tasks`, that can be deployed during an update. For example, if you have 4 Tasks running at version
  1, `deployment_maximum_percent` is set to 200, and you kick off a deployment of version 2 of your Task, ECS will
  first deploy 4 Tasks at version 2, wait for them to come up, and then it'll undeploy the 4 Tasks at version 1. Note
  that this only works if your ECS cluster has capacity--that is, EC2 instances with the available memory, CPU, ports,
  etc requested by your Tasks, which might mean maintaining several empty EC2 instances just for deployment.
* `deployment_minimum_healthy_percent`: This variable controls the minimum number of copies of your ECS Task, as a
  percentage of `desired_number_of_tasks`, must stay running during an update. For example, if you have 4 Tasks running
  at version 1, you set `deployment_minimum_healthy_percent` to 50, and you kick off a deployment of version 2 of your
  Task, ECS will first undeploy 2 Tasks at version 1, then deploy 2 Tasks at version 2 in their place, and then repeat
  the process again with the remaining 2 tasks. This allows you to roll out new versions without having to keep spare
  EC2 instances, but it also means the availability of your service is somewhat reduced during rollouts.

## How do I do a canary deployment?

A [canary deployment](http://martinfowler.com/bliki/CanaryRelease.html) is a way to test new versions of your Docker
containers in a way that limits the damage any bugs could do. The idea is to deploy the new version onto just a single
server (meanwhile, the old versions are running elsewhere) and to test that new version and compare it to the old
versions. If everything is working well, you roll the new version out everywhere. If there are any problems, they only
affect a small percentage of users, and you can quickly fix them by rolling the new version back.

To do a canary deployment with this module, you need to specify two parameters:

* `canary_task_arn`: The ARN of the ECS Task to deploy as a canary.
* `desired_number_of_canary_tasks_to_run`: The number of ECS Tasks to run for the canary. You should typically set
  this to 1.

Here's an example that has 10 versions of the original ECS Task running and adds 1 Task to try out a canary:

```hcl
module "ecs_service" {
  task_arn = "${aws_ecs_task_definition.original_task.arn}"
  desired_number_of_tasks = 10

  canary_task_arn = "${aws_ecs_task_definition.canary_task.arn}"
  desired_number_of_canary_tasks_to_run = 1

  # (... all other params omitted ...)
}
```

If this canary has any issues, set `desired_number_of_canary_tasks_to_run` to 0. If the canary works well, to
deploy the new version across the whole cluster, update `aws_ecs_task_definition.original_task` with the new version of
the Docker container and set `desired_number_of_canary_tasks_to_run` back to 0.

## How does canary deployment work?

The way we do canary deployments with this module is to create a second ECS Service just for the canary that runs
`desired_number_of_canary_tasks_to_run` instances of your canary ECS Task. This ECS Service registers with the same
ELB (if you're using one), so some percentage of user requests will randomly hit the canary, and the rest will go to
the original ECS Tasks. For example, if you had 9 ECS Tasks and you deployed 1 canary ECS Task, then each request would
have a 90% chance of hitting the original version of your Docker container and a 10% chance of hitting the canary
version.

Therefore, there are two caveats with using canary deployments:

1. Do not do canary deployments with user-visible changes. For example, if your Docker container is a frontend service
   and the new Docker image version changes the UI, then a user may see a different version of the UI every time they
   refresh the page, which could be a jarring experience. You can still use canary deployments with frontend Docker
   containers so long as you wrap UI changes in feature toggles and don't enable those toggles until the new version is
   rolled out across the entire cluster (i.e. this is known as a [dark
   launch](http://tech.co/the-dark-launch-how-googlefacebook-release-new-features-2016-04)).
1. Ensure the new version of your Docker container is backwards compatible with the old version. For example, if the
   Docker container runs schema migrations when it boots, make sure the new schema works correctly with the old version
   of the Docker container, since both will be running simultaneously. Backwards compatibility is always a good idea
   with deployments, but it becomes a hard requirement with canary deployments.

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

## How do you scale an ECS Service?

To scale an ECS service in response to higher load, you have two options:

1. **Scale the number of ECS Tasks**: To do this, you first create an
   [aws_appautoscaling_target](https://www.terraform.io/docs/providers/aws/r/appautoscaling_target.html), setting its
   `role_arn` parameter to the `service_autoscaling_iam_role_arn` of the `ecs-service` module. Next, you create one or
   more [aws_appautoscaling_policy](https://www.terraform.io/docs/providers/aws/r/appautoscaling_policy.html)
   resources that define how to scale the number of ECS Tasks up or down. Finally, you create one or more
   [aws_cloudwatch_metric_alarm](https://www.terraform.io/docs/providers/aws/r/cloudwatch_metric_alarm.html) resources
   that trigger your `aws_appautoscaling_policy` resources when certain metrics cross specific thresholds (e.g. when
   CPU usage is over 90%).
1. **Scale the number of ECS Instances and Tasks**: If your ECS Cluster doesn't have enough spare capacity, then not
   only will you have to scale the number of ECS Tasks as described above, but you'll also have to increase the
   size of the cluster by scaling the number of ECS Instances. To do that, you create one or more
   [aws_autoscaling_policy](https://www.terraform.io/docs/providers/aws/r/autoscaling_policy.html) resources with the
   `autoscaling_group_name` parameter set to the `ecs_cluster_asg_name` output of the `ecs-cluster` module. Next, you
   create one or more
   [aws_cloudwatch_metric_alarm](https://www.terraform.io/docs/providers/aws/r/cloudwatch_metric_alarm.html) resources
   that trigger your `aws_autoscaling_policy` resources when certain metrics cross specific thresholds (e.g. when
   CPU usage is over 90%).

See the [docker-service-with-autoscaling example](/examples/docker-service-with-autoscaling) for sample code.
