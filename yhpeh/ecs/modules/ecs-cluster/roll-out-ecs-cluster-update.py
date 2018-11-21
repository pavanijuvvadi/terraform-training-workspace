import os
import logging
import boto3
import json
import time
import argparse
from exceptions import LookupError

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

SLEEP_BETWEEN_RETRIES_SEC = 10

"""Parse the arguments passed to this script
"""
def parse_args():
    parser = argparse.ArgumentParser(description='Roll out an update to an ECS Cluster Auto Scaling Group with zero downtime.')

    parser.add_argument('--asg-name', required=True, help='The name of the Auto Scaling Group')
    parser.add_argument('--cluster-name', required=True, help='The name of the ECS Cluster')
    parser.add_argument('--aws-region', required=True, help='The AWS region to use')
    parser.add_argument('--timeout', help='The maximum amount of time, in seconds, to wait for deployment to complete before timing out.', default=900)

    return parser.parse_args()


"""The main entrypoint for this script, which does the following:

   1. Double the desired capacity of the ASG, which will cause Instances to deploy with the new launch configuration.
   2. Put all the old Instances in DRAINING state so all ECS Tasks are migrated off of them to the new Instances.
   3. Wait for all ECS Tasks to migrate off the old Instances.
   4. Set the desired capacity of the ASG back to its original value.
"""
def do_rollout():
    args = parse_args()

    session = boto3.session.Session(region_name=args.aws_region)
    ecs_client = session.client('ecs')
    asg_client = session.client('autoscaling')

    logger.info('Beginning roll out for ECS cluster %s in %s', args.cluster_name, args.aws_region)

    start = time.time()
    original_capacity = get_asg_capacity(asg_client, args.asg_name)
    container_instance_arns = get_container_instance_arns(ecs_client, args.cluster_name)

    set_asg_capacity(asg_client, args.asg_name, original_capacity * 2)
    put_container_instances_in_draining_state(ecs_client, args.cluster_name, container_instance_arns)
    wait_for_container_instances_to_drain(ecs_client, args.cluster_name, container_instance_arns, start, args.timeout)
    set_asg_capacity(asg_client, args.asg_name, original_capacity)

    logger.info('Roll out for ECS cluster %s complete!', args.cluster_name)


"""Return the desired capacity of an Auto Scaling Group.
"""
def get_asg_capacity(asg_client, asg_name):
    logger.info('Looking up size of ASG %s', asg_name)

    output = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])

    asgs = output.get('AutoScalingGroups', [])
    if len(asgs) != 1:
        raise LookupError('Expected to find one Auto Scaling Group named %s but found %d' % (asg_name, len(asgs)))

    desired_capacity = asgs[0].get('DesiredCapacity')
    if desired_capacity is None:
        raise LookupError('Could not find a desired capacity for ASG %s', asg_name)

    return desired_capacity


"""Set the desired capacity of an Auto Scaling Group.
"""
def set_asg_capacity(asg_client, asg_name, desired_capacity):
    logger.info('Setting desired capacity of ASG %s to %d', asg_name, desired_capacity)
    asg_client.set_desired_capacity(AutoScalingGroupName=asg_name, DesiredCapacity=desired_capacity)


"""Get the Instance ARNs of all the Instances in an ECS Cluster. Note that ECS Instance ARNs are NOT the same thing as
   EC2 Instance IDs.
"""
def get_container_instance_arns(ecs_client, cluster_name):
    logger.info('Looking up Cluster Instance ARNs for ECS cluster %s', cluster_name)
    arns = []
    nextToken = ''

    while True:
        cluster_instances = ecs_client.list_container_instances(cluster=cluster_name, nextToken=nextToken)
        arns.extend(cluster_instances['containerInstanceArns'])

        # If there are more than 100 instances in the cluster, the nextToken param can be used to paginate through them
        # all.
        nextToken = cluster_instances.get('nextToken')
        if not nextToken:
            return arns


"""Put ECS Instances in DRAINING state so that all ECS Tasks running on them are migrated to other Instances.
"""
def put_container_instances_in_draining_state(ecs_client, cluster_name, container_instance_arns):
    logger.info('Putting container instances %s in cluster %s into DRAINING state', container_instance_arns, cluster_name)
    ecs_client.update_container_instances_state(cluster=cluster_name, containerInstances=container_instance_arns, status='DRAINING')


"""Wait until there are no more ECS Tasks running on any of the ECS Instances.
"""
def wait_for_container_instances_to_drain(ecs_client, cluster_name, container_instance_arns, start, timeout):
    while not max_execution_time_exceeded(start, timeout):
        logger.info('Checking if all ECS Tasks have been drained from the ECS Instances in Cluster %s', cluster_name)

        response = ecs_client.describe_container_instances(
            cluster=cluster_name,
            containerInstances=container_instance_arns
        )

        if all_instances_fully_drained(response):
            logger.info('All instances have been drained in Cluster %s!', cluster_name)
            return
        else:
            logger.info("Will sleep for %d seconds and check again", SLEEP_BETWEEN_RETRIES_SEC)
            time.sleep(SLEEP_BETWEEN_RETRIES_SEC)

    raise Exception('Maximum drain timeout of %s seconds has elapsed and instances are still draining.', timeout)


"""Return True if the amount of time since start has exceeded the timeout
"""
def max_execution_time_exceeded(start, timeout):
    now = time.time()
    elapsed = now - start
    return elapsed > timeout


"""Return True if the Instances in there are no more ECS Tasks running on the ECS Instances in the response from the
   describe_container_instances API
"""
def all_instances_fully_drained(describe_container_instances_response):
    instances = describe_container_instances_response.get('containerInstances')
    if not instances:
        raise LookupError("The describe_container_instances returned no instances")

    for instance in instances:
        if not instance_fully_drained(instance):
            return False

    return True


"""Return True if the given Instance, as returned by the describe_container_instances API, has no more ECS Tasks
   running on it.
"""
def instance_fully_drained(instance):
    instance_arn = instance.get('containerInstanceArn')

    if instance.get('status') == 'ACTIVE':
        logger.info('The ECS Instance %s is still in ACTIVE status', instance_arn)
        return False


    if instance.get('pendingTasksCount') > 0:
        logger.info('The ECS Instance %s still has pending tasks', instance_arn)
        return False

    if instance.get('runningTasksCount') > 0:
        logger.info('The ECS Instance %s still has running tasks', instance_arn)
        return False

    return True

do_rollout()
