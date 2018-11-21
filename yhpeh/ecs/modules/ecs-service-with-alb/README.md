# ECS Service with ALB

This Terraform Module creates an [EC2 Container Service
Service](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html) that you can use to run one or
more related, long-running Docker containers, such as a web service, fronted by an [Application Load 
Balancer](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) as created by the 
Gruntwork [alb module](https://github.com/gruntwork-io/module-load-balancer/tree/master/modules/alb). An ECS service can 
automatically deploy multiple instances of your Docker containers across an ECS cluster (see the [ecs-cluster module]
(../ecs-cluster)), and restart any failed Docker containers.

This module also supports [canary deployment](http://martinfowler.com/bliki/CanaryRelease.html), where you can deploy a
single instance of a new Docker container version, test it, and if everything works well, deploy that version across
the rest of the cluster.

**If you wish to deploy an ECS Service with a Classic Load Balancer (ELB), or no load balancer at all, see the [ecs-service
module](../ecs-service).**

**This module does NOT create any [ALB Listener Rules](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules).
In order to route inbound ALB traffic to this ECS Service, you must separately add one or more Terraform [aws_alb_listener_rule](https://www.terraform.io/docs/providers/aws/r/alb_listener_rule.html)
resources.**

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See the [examples](/examples) folder for example usage.
* See [vars.tf](./vars.tf) for all the variables you can set on this module.
* This module assumes you have already deployed:
  * An ECS Cluster: See the [ecs-cluster module](../ecs-cluster) for how to run one.
  * An ALB: See the [alb module](https://github.com/gruntwork-io/module-load-balancer/tree/master/modules/alb) for how to
    create an ALB that will route requests to this ECS Service.
* This module uses the `ecs-deployment-check` binary available
  under
  [ecs-deploy-check-binaries](../ecs-deploy-check-binaries) to
  have a more robust check for the service deployment. You
  must have `python` installed before you can use this check.
  See the binary [README](../ecs-deploy-check-binaries) for
  more information. You can disable the check by setting the
  module variable `enable_ecs_deployment_check` to `false`.


## Common Questions

### First, see the ecs-service module.

See the [ecs-service module](../ecs-service) for additional information on what is an ECS Service, how to do canary
deployments, and more.

### What are all the AWS resources required to run an ECS Service fronted by an ALB?

In AWS, to create an ECS Service, we need the following resources:

- ALB
  - [ALB itself](https://www.terraform.io/docs/providers/aws/r/alb.html): This is the load balancer that receives inbound
    requests and routes them to our ECS Service. 
  - [ALB Listener](https://www.terraform.io/docs/providers/aws/r/alb_listener.html): An ALB will only listen for incoming
    traffic on ports for which there is an ALB Listener defined. For example, if you want the ALB to accept traffic on 
    port 80, you must define an ALB Listener for port 80.
  - [ALB Listener Rule](https://www.terraform.io/docs/providers/aws/r/alb_listener_rule.html): Once an ALB Listener
    receives traffic, which [ALB Target Group](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) 
    (Docker containers) should it route the requests to? We must define ALB Listener Rules that route inbound requests
    based on either their hostname (e.g. `gruntwork.io` vs `amazon.com`), their path (e.g. `/foo` vs. `/bar`), or both.
  - [ALB Target Group](https://www.terraform.io/docs/providers/aws/r/alb_target_group.html): The ALB Listener Rule routes
    requests by determining a "Target Group". It then picks one of the [Targets](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#registered-targets)
    in the Target Group (typically, a Docker container or EC2 Instance) as the final destination for the request.  
  
- ECS Cluster
  - [ECS Cluster itself](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html): The ECS Cluster is where all
    our Docker containers are run.

- ECS Service
  - [ECS Task Definition](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html): To define which Docker
    image we want to run, how much memory/CPU to allocate it, which `docker run` commmand to use, environment variables,
    and [every other aspect of the Docker container configuration](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html), 
    we create an "ECS Task Definition". The idea behind the name is that an ECS Cluster could, in theory, run many types
    of tasks, and Docker is just one such type. Therefore, rather than calling tasks "Docker containers", Amazon uses 
    the name "ECS Task".
  - [ECS Service itself](https://www.terraform.io/docs/providers/aws/r/ecs_service.html): When we want to run multiple 
    ECS Tasks as part of a single service (i.e. run multiple Docker containers as part of a single service), enable
    auto-restart if a container fails, and enable the ALB to automatically discover newly launched ECS Tasks, we create
    an "ECS Service".
    
To clarify the relationship between these entities:

When creating your ALB, ECS Cluster, and ECS Service for the first time:
  - First create your ALB (see module [alb](https://github.com/gruntwork-io/module-load-balancer/tree/master/modules/alb))
  - Then create your ECS Cluster (see module [ecs-cluster](../ecs-cluster))
  - Finally, create your ECS Service (this module!)
  
When creating a new ECS Service that uses an existing ALB and existing ECS Cluster:
  - Simply create your ECS Service (this module!), and specify the desired ALB and ECS Cluster using the [module vars](vars.tf)
  
Note that:
  - An ECS Cluster may have one or more ECS Services
  - An ECS Service may be associated with zero or one ALBs 
  - An ALB may be shared among multiple ECS Services
  - An ALB has zero or more ALB Listeners
  - Each ALB Listener has zero or more ALB Listener Rules
  - An ALB Target Group may receive traffic from zero or more ALBs  

### Which AWS resources are created by which Gruntwork modules?

Compared to other AWS services, there is more essential complexity in setting up an ECS Service fronted by an ALB because
of the interrelationships between all the resources. Our goal in creating a Terraform modules was to present a simple
set of interfaces to make creating an ECS Service as intuitive as possible. Here's how it breaks down:

- Module [alb](https://github.com/gruntwork-io/module-load-balancer/tree/master/modules/alb) creates:
  - ALB itself
  - ALB Listener(s)
  - A single ALB Target group called `blackhole`. An ALB Listener requires that we specify a "default" Target Group where
    requests will be routed if no ALB Listener Rules match, but we want all our ALB Listener Rules defined outside this
    module (e.g. in the `ecs-service-with-alb` module) so our default `blackhole` Target Group is meant only to indicate
    that no Targets will ever actually be placed in the `blackhole` Target Group. 

- Module `ecs-service-with-alb` (this module) creates:
  - ECS Service itself
  - ECS Task Definition
  - ALB Target Group for the ECS Tasks
  - But note that the module does NOT create any ALB Listener Rules! That's because we want to give users maximum flexibility
    to define their own arbitrary ALB Listener Rules. Therefore, we recommend creating ALB Listener Rules as shown in
    the [example](../../examples/docker-service-with-alb/main.tf).

- Module [ecs-cluster](../ecs-cluster) creates:
  - ECS Cluster itself

### Why doesn't this module create [ALB Listener Rules](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules) directly?

In the first version of this module, we attempted to hide the creation of ALB Listener Rules from users. Our thought process
was that the module's API should simplify as much as possible what was actually happening. But in practice we found that
there was more variation than we expected in the different routing rules that customers required, that supporting any
new ALB Listener Rule type (e.g. host-based routing) was cumbersome, and that by wrapping so much complexity, we ultimately
created more confusion, not less.

For this reason, the intent of this module is now about creating an ECS Service that is *ready* to be routed to. But to
complete the configuration, the Terraform code that calls this module should directly create its own set of Terraform
[alb_listener_rule](https://www.terraform.io/docs/providers/aws/r/alb_listener_rule.html) resources to meet the specific
needs of your ECS Cluster.  

### How do you add additional IAM policies to the ECS Service?

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

## Known Issues

### Switching the value of `var.use_alb_sticky_sessions`

If you switch `var.use_alb_sticky_sessions` from true to false or vice versa, Terraform will attempt to destroy and 
re-create the `aws_alb_target_group` which has a chain of dependencies that eventually lead to destroying and re-creating 
the ECS Service, which will lead to downtime. This is because we conditionally create Terraform resources depending on
the value of`var.use_alb_sticky_sessions`, and Terraform can't fully incorporate this concept into its dependency graph.
   
Fortunately, there's a workaround using manual state manipulation. We'll tell Terraform that the old resource is now 
the new one as follows.
   
```
# If you are changing var.use_alb_sticky_sessions from TRUE to FALSE:
terraform state mv module.ecs_service.aws_alb_target_group.ecs_service_with_sticky_sessions module.ecs_service.aws_alb_target_group.ecs_service_without_sticky_sessions

# If you are changing var.use_alb_sticky_sessions from FALSE to TRUE:
terraform state mv module.ecs_service.aws_alb_target_group.ecs_service_without_sticky_sessions module.ecs_service.aws_alb_target_group.ecs_service_with_sticky_sessions
```

Now run `terragrunt plan` to confirm that Terraform will only make modifications.
