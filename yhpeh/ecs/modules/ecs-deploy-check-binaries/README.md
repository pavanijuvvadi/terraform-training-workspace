# ECS Deploy Check Scripts

This folder contains helper binaries used to check the status of an
ECS deployment from the terraform modules. These binaries are used to workaround
the limitations of terraform in checking the successful deployment of ECS
services.

### Why not rely on the existing terraform deployment results?

Terraform's ECS modules simply check if the deployment of a task has been
scheduled to the cluster and does not actually check whether or not the
deployment was successful. As such, you can encounter failure scenarios where
the deployment fails due to various circumstances (e.g cluster does not have
enough capacity) but terraform returns a successful status. These binaries are
designed to ensure the task has actually been scheduled on the cluster and is
healthy.


## Available Binaries

* `check-ecs-service-deployment`: This binary checks the status of a ECS
  service and verifies that the requested tasks have been successfully
  scheduled on the cluster. Specifically, this binary will:

    - Check that the expected task definition is deployed and active on the service
    - [optional] Check that the ALB/NLB healthcheck is returning successfully on the service
      (does not work with ELB classic)


### Requirements for running

The host machine must have a valid python interpreter available in the `PATH`
under the name `python`. The binary supports python versions 2.7, 3.5, 3.6, and
3.7.


## Using the check-ecs-service-deployment helper

The helper binary is intended to be used as a [local exec
provisioner](https://www.terraform.io/docs/provisioners/local-exec.html). The
directives for the helper are already included as part of the various terraform
modules for ECS included in this repository. The helper will exit with a
failure if the ECS service fails any of the checks included with the helper,
thus causing the terraform deployment to fail. You can configure the behavior
of the checks through various module options provided by the ECS service
modules in this repository. Refer to the available vars in each module for more
details.

However, if you wish to run it yourself, the `check-ecs-service-deployment`
binary has the following prerequisites:

1. It must be run on the host machine executing terraform.
1. AWS credentials must be configured on the host machine using either a
   credentials file or environment variables.

To run the binary, you need to pass it the name of the ECS cluster, the
service to check, and the desired task definition that is supposed to be
running on the service as command line arguments:

```bash
check-ecs-service-deployment --aws-region us-east-1 --ecs-cluster-name my-ecs-cluster --ecs-service-name my-ecs-service --ecs-task-definition nginx:1
```

You can also use the optional `--check-timeout-seconds` parameter to configure
how many seconds to wait before timing out each check and declaring that the
task has failed to deploy. Note that the timeout resets after
each check, so the total timeout for the full check will by
2x this value. This will default to 600.

Additionally, you can skip the load balancer checks using the optional
`--no-loadbalancer` parameter. This will tell the binary to only check for the
tasks to be active.

Also, if you are checking the deployment of [daemon
services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html#service_scheduler_daemon),
provide the `--daemon-check` option, which will cause the helper to validate
that the task is running on all container instances.

You can see all the available and required options via the help command for the helper:

```bash
check-ecs-service-deployment --help
```


## Building the check-ecs-service-deployment helper

The `check-ecs-service-deployment` binary is a python binary with all the
necessary requirements baked into the binary as a wheel using the
[`pex`](https://pex.readthedocs.io/en/stable/whatispex.html) utility.

To build the binary, you will need the following:

- A working python environment with both python2 and python3 setup (so that you
  can build binaries for both environments)
- tox and pex installed (use `pip install -r dev_requirements.txt`)

You can then build the binary using the helper script `build.sh` which will build
the binary and copy it to the `bin` directory for distribution.

It is recommended to use
[`pyenv`](https://github.com/pyenv/pyenv) to help setup an
environment with multiple python interpreters. The latest binaries are built
with the following python environment:

```bash
pyenv shell 2.7.15 3.5.2 3.6.6 3.7.0
```
