# ECS Modules

This repo contains modules for running Docker containers on top of [Amazon EC2 Container Service
(ECS)](https://aws.amazon.com/ecs/). The modules are:
    
* [ecs-cluster](/modules/ecs-cluster): Deploy a cluster of EC2 instances that ECS can use for running Docker
  containers.
* [ecs-service](/modules/ecs-service): Deploy an ECS Service, which is a way to run one or more related, long-running
  Docker containers, such as a web service. An ECS service can automatically deploy multiple instances of your Docker
  containers across an ECS cluster, restart any failed Docker containers, and route traffic across your containers
  using an optional Elastic Load Balancer (ELB).
* [ecs-fargate](/modules/ecs-fargate): Deploy a Fargate Service, which is a way to run one or more related, long-running
  Docker containers, such as a web service. A Fargate service can automatically deploy multiple instances of your Docker
  containers without you having to concern yourself with deploying, configuring or scaling the underlying instances. Just
  ask AWS to deploy your containers and it handles the rest.
* [ecs-service-with-alb](/modules/ecs-service-with-alb): Deploy an ECS Service fronted by an Application Load Balancer
  (ALB). This is especially useful for a traditional HTTP-based service, or one that uses WebSockets.
* [ecs-scripts](/modules/ecs-scripts): Helper scripts you can run on the EC2 instances in your ECS cluster to
  initialize and configure them.
* [ecs-deploy](/modules/ecs-deploy): Scripts that help with ECS deployment, such as running a single ECS Task, waiting
  for it to exit, and returning its exit code.

## What is a module?

At [Gruntwork](http://www.gruntwork.io), we've taken the thousands of hours we spent building infrastructure on AWS and
condensed all that experience and code into pre-built **packages** or **modules**. Each module is a battle-tested,
best-practices definition of a piece of infrastructure, such as a VPC, ECS cluster, or an Auto Scaling Group. Modules
are versioned using [Semantic Versioning](http://semver.org/) to allow Gruntwork clients to keep up to date with the
latest infrastructure best practices in a systematic way.

## How do you use a module?

Most of our modules contain either:

1. [Terraform](https://www.terraform.io/) code
1. Scripts & binaries

#### Using a Terraform Module

To use a module in your Terraform templates, create a `module` resource and set its `source` field to the Git URL of
this repo. You should also set the `ref` parameter so you're fixed to a specific version of this repo, as the `master`
branch may have backwards incompatible changes (see [module
sources](https://www.terraform.io/docs/modules/sources.html)).

For example, to use `v1.0.8` of the ecs-cluster module, you would add the following:

```hcl
module "ecs_cluster" {
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-cluster?ref=v1.0.8"

  // set the parameters for the ECS cluster module
}
```

*Note: the double slash (`//`) is intentional and required. It's part of Terraform's Git syntax (see [module
sources](https://www.terraform.io/docs/modules/sources.html)).*

See the module's documentation and `vars.tf` file for all the parameters you can set. Run `terraform get -update` to
pull the latest version of this module from this repo before runnin gthe standard  `terraform plan` and
`terraform apply` commands.

#### Using scripts & binaries

You can install the scripts and binaries in the `modules` folder of any repo using the [Gruntwork
Installer](https://github.com/gruntwork-io/gruntwork-installer). For example, if the scripts you want to install are
in the `modules/ecs-scripts` folder of the https://github.com/gruntwork-io/module-ecs repo, you could install them
as follows:

```bash
gruntwork-install --module-name "ecs-scripts" --repo "https://github.com/gruntwork-io/module-ecs" --tag "0.0.1"
```

See the docs for each script & binary for detailed instructions on how to use them.

## What is EC2 Container Service?

EC2 Container Service (ECS) is the official AWS solution for running Docker containers on EC2 instances in a
fault-tolerant, scalable, and highly available way. Its primary advantage over alternatives like
[Mesos](http://mesos.apache.org/) and [Kubernetes](http://kubernetes.io/) is that it's much easier to set up,
understand, and integrate with other AWS services. Its primary downside is that it offers less powerful options for
"scheduling" containers across different hosts.

## What is Fargate?

Fargate is a technology for Amazon ECS that allows you to run containers without having to manage servers or clusters. With AWS Fargate, you no longer have to provision, configure, and scale clusters of virtual machines to run containers. This removes the need to choose server types, decide when to scale your clusters, or optimize cluster packing.

### ECS vs Fargate

#### ECS Functionality

- You have full control over the servers and how they are configured.
- You deploy, maintain, patch, monitor, and scale the servers yourself.
- You can control costs with spot instances and reserved instances.
- You can use Docker images in private registeries.
- You have to manually monitor the EC2 instances in your cluster.
- Supports Classic Load Balancers, Application Load Balancers and Network Load Balancers

#### Fargate Functionality

- You hand AWS a container and it figures out how to deploy it. You don't have to worry about the servers at all, just your app/containers.
- Fargate could be slightly more expensive than ECS because of the lack of fine grained control over the instance sizes. Detailed pricing breakdown [here](https://aws.amazon.com/fargate/pricing/)
- Fargate starts up containers slightly slower because of the overhead of newly creating the underlying infrastructure.
- Fargate doesn't support all Task Definition parameters, more info [here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-task-defs)
- Fargate only supports images in Amazon ECR or public repositories in Docker Hub.
- Fargate automatically sets up Cloudwatch metric and logs for your service.
- Fargate is limited to Application Load Balancers and Network Load Balancers
- Fargate is currently not supported in all regions. See the full support matrix [here](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/)


Which service you decide to go with is entirely dependent on your infrastructure needs. If you want to focus entirely on the application you're deploying and not have to worry about servers, clusters and the underlying infrastructure as a whole then Fargate is for you. However, if your application does require you to have fine grained control over the details of the underlying EC2 instances, auto scaling rules etc than ECS is more appropriate.

### Helpful Vocabulary

Amazon has its own vocabulary for ECS that can be confusing. Here's a helpful guide:

- **ECS Cluster:** One or more servers (i.e. EC2 instances) that ECS can use for deploying Docker containers.
- **Container Instance:** A single node (i.e. EC2 Instance) in an ECS Cluster.
- **ECS Task:** One or more Docker containers that should be run as a group on a single instance.
- **ECS Task Definition (AKA ECS Container Definition):** A JSON file that defines an ECS Task, including the
  container(s) to run, the resources (memory, CPU) those containers need, the volumes to mount, the environment
  variables to set, and so on.
- **Task Definition Revision:** ECS Tasks are immutable. Once you define a Task Definition, you can never change it:
  you can only create new Task Definitions, which are known as revisions. The most common revision is to change what
  version of a Docker container to deploy.
- **ECS Service:** A way to deploy and manage long-running ECS Tasks, such as a web service. The service can deploy
  your Tasks across one or more instances in the ECS Cluster, restart any failed Tasks, and route traffic across your
  Tasks using an optional Elastic Load Balancer.

## Developing a module

### Formatting and pre-commit hooks

You must run `terraform fmt` on the code before committing. You can configure your computer to do this automatically 
using pre-commit hooks managed using [pre-commit](http://pre-commit.com/):

1. [Install pre-commit](http://pre-commit.com/#install). E.g.: `brew install pre-commit`.
1. Install the hooks: `pre-commit install`.

That's it! Now just write your code, and every time you commit, `terraform fmt` will be run on the files you're 
committing.

### Versioning

We are following the principles of [Semantic Versioning](http://semver.org/). During initial development, the major
version is to 0 (e.g., `0.x.y`), which indicates the code does not yet have a stable API. Once we hit `1.0.0`, we will
follow these rules:

1. Increment the patch version for backwards-compatible bug fixes (e.g., `v1.0.8 -> v1.0.9`).
2. Increment the minor version for new features that are backwards-compatible (e.g., `v1.0.8 -> 1.1.0`).
3. Increment the major version for any backwards-incompatible changes (e.g. `1.0.8 -> 2.0.0`).

The version is defined using Git tags.  Use GitHub to create a release, which will have the effect of adding a git tag.

### Tests

See the [test](/test) folder for details.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.