# ECS Cluster Module

This Terraform Module launches an [EC2 Container Service
Cluster](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_clusters.html) that you can use to run
Docker containers and services (see the [ecs-service module](../ecs-service)).

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See the [examples](/examples) folder for example usage.
* See [vars.tf](./vars.tf) for all the variables you can set on this module.
* See the [ecs-service module](../ecs-service) for how to run Docker containers across this cluster.

## What is an ECS Cluster?

To use ECS, you first deploy one or more EC2 Instances into a "cluster". The ECS scheduler can then deploy Docker
containers across any of the instances in this cluster. Each instance needs to have the [Amazon ECS
Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) installed so it can communicate with
ECS and register itself as part of the right cluster.

## How do you run Docker containers on the cluster?

See the [service module](../service).

## How do you add additional security group rules?

To add additional security group rules to the EC2 Instances in the ECS cluster, you can use the
[aws_security_group_rule](https://www.terraform.io/docs/providers/aws/r/security_group_rule.html) resource, and set its
`security_group_id` argument to the Terraform output of this module called `ecs_instance_security_group_id`. For
example, here is how you can allow the EC2 Instances in this cluster to allow incoming HTTP requests on port 8080:

```hcl
module "ecs_cluster" {
  # (arguments omitted)
}

resource "aws_security_group_rule" "allow_inbound_http_from_anywhere" {
  type = "ingress"
  from_port = 8080
  to_port = 8080
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${module.ecs_cluster.ecs_instance_security_group_id}"
}
```

**Note**: The security group rules you add will apply to ALL Docker containers running on these EC2 Instances. There is
currently no way in ECS to manage security group rules on a per-Docker-container basis.

## How do you add additional IAM policies?

To add additional IAM policies to the EC2 Instances in the ECS cluster, you can use the
[aws_iam_role_policy](https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html) or
[aws_iam_policy_attachment](https://www.terraform.io/docs/providers/aws/r/iam_policy_attachment.html) resources, and
set the IAM role id to the Terraform output of this module called `ecs_instance_iam_role_name` . For example, here is how
you can allow the EC2 Instances in this cluster to access an S3 bucket:

```hcl
module "ecs_cluster" {
  # (arguments omitted)
}

resource "aws_iam_role_policy" "access_s3_bucket" {
    name = "access_s3_bucket"
    role = "${module.ecs_cluster.ecs_instance_iam_role_name}"
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

**Note**: The IAM policies you add will apply to ALL Docker containers running on these EC2 Instances. There is
currently no way in ECS to manage IAM policies on a per-Docker-container basis.

## How do you make changes to the EC2 Instances in the cluster?

To deploy an update to an ECS Service, see the [ecs-service module](/modules/ecs-service). To deploy an update to the
EC2 Instances in your ECS cluster, such as a new AMI, read on.

Terraform and AWS do not provide a way to automatically roll out a change to the Instances in an ECS Cluster. Due to
Terraform limitations (see [here for a discussion](https://github.com/gruntwork-io/module-ecs/pull/29)), there is 
currently no way to implement this purely in Terraform code. Therefore, we've created a script called 
`roll-out-ecs-cluster-update.py` that can do a zero-downtime roll out for you.

### How to use the roll-out-ecs-cluster-update.py script

First, make sure you have the latest version of the [AWS Python SDK (boto3)](https://github.com/boto/boto3) installed
(e.g. `pip install boto3`).

To deploy a change such as rolling out a new AMI to all ECS Instances:

1. Make sure the `cluster_max_size` is at least twice the size of `cluster_min_size`. The extra capacity will be used 
   to deploy the updated instances.
1. Update the Terraform code with your changes (e.g. update the `cluster_instance_ami` variable to a new AMI).
1. Run `terraform apply`.
1. Run the script: 

    ```
    python roll-out-ecs-cluster-update.py --asg-name ASG_NAME --cluster-name CLUSTER_NAME --aws-region AWS_REGION
    ```
    
    If you have your output variables configured as shown in [outputs.tf](/examples/docker-service-with-elb/outputs.tf)
    of the [docker-service-with-elb example](/examples/docker-service-with-elb), you can use the `terraform output`
    command to fill in most of the arguments automatically:
    
    ```
    python roll-out-ecs-cluster-update.py \
      --asg-name $(terragrunt output -no-color asg_name) \
      --cluster-name $(terragrunt output -no-color ecs_cluster_name) \
      --aws-region $(terragrunt output -no-color aws_region)    
    ```

### How roll-out-ecs-cluster-update.py works

The `roll-out-ecs-cluster-update.py` script does the following:

1. Double the desired capacity of the Auto Scaling Group that powers the ECS Cluster. This causes ECC Instances to 
   deploy with the new launch configuration.
1. Put all the old ECS Instances in DRAINING state so all ECS Tasks are migrated off of them to the new Instances.
1. Wait for all ECS Tasks to migrate off the old Instances.
1. Set the desired capacity of the Auto Scaling Group back to its original value.

