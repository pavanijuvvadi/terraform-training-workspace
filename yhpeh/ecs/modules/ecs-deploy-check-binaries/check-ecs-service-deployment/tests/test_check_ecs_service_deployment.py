import json
import unittest
import boto3
import moto
from moto.ec2 import utils as ec2_utils

import check_ecs_service_deployment.checker as checker


class CheckECSServiceDeploymentTestCaseMixin(object):
    """
    Mixin test cases that defines all the core tests. This is then extended by
    `CheckECSServiceDeploymentALBTestCase` and `CheckECSServiceDeploymentNLBTestCase`
    to test core functionality against ALB and NLB respectively.

    Note that this doesn't directly inherit from
    unittest.TestCase to avoid having the tests run directly
    from the mixin.
    """

    def setUp(self):
        # Use moto to setup a mock AWS service that works inmemory
        self.mock_ec2 = moto.mock_ec2()
        self.mock_ec2.start()
        self.mock_ecs = moto.mock_ecs()
        self.mock_ecs.start()
        self.mock_elbv2 = moto.mock_elbv2()
        self.mock_elbv2.start()

        self.ecs_client = boto3.client('ecs', region_name='us-east-1')
        self.ec2_client = boto3.resource('ec2', region_name='us-east-1')
        self.elb_client = boto3.client('elbv2', region_name='us-east-1')
        self.cluster, self.service, self.task_definition, self.container_instance_id = self.setup_ecs_resources()
        self.start_task(self.container_instance_id)

    def tearDown(self):
        self.mock_ec2.stop()
        self.mock_ecs.stop()
        self.mock_elbv2.stop()

    def setup_ecs_resources(self):
        # Setup a test ECS cluster with a task definition already registered
        test_cluster_name = 'test_ecs_cluster'
        cluster = self.ecs_client.create_cluster(clusterName=test_cluster_name)
        task_definition = self.ecs_client.register_task_definition(
            family='test_ecs_task',
            containerDefinitions=[
                {
                    'name': 'hello_world',
                    'image': 'docker/hello-world:latest',
                    'cpu': 1024,
                    'memory': 400,
                    'essential': True,
                    'environment': [{
                        'name': 'AWS_ACCESS_KEY_ID',
                        'value': 'SOME_ACCESS_KEY'
                    }],
                    'logConfiguration': {'logDriver': 'json-file'}
                }
            ]
        )
        # ... and then register a service for that task with a load balancer targeting it
        load_balancer, target_group = self.setup_elb_resources()
        service = self.ecs_client.create_service(
            cluster=test_cluster_name,
            serviceName='test_ecs_service',
            taskDefinition='test_ecs_task',
            desiredCount=2,
            loadBalancers=[
                {
                    'targetGroupArn': target_group['TargetGroupArn'],
                    'loadBalancerName': load_balancer['LoadBalancerName'],
                    'containerName': 'test_container_name',
                    'containerPort': 123
                }
            ]
        )

        # The mock ecs service will not "start" the task for us, nor does it
        # create the instances, so we must simulate it ourselves
        test_instance = self.ec2_client.create_instances(
            ImageId="ami-1234abcd",
            MinCount=1,
            MaxCount=1,
        )[0]
        instance_id_document = json.dumps(
            ec2_utils.generate_instance_identity_document(test_instance)
        )

        self.ecs_client.register_container_instance(
            cluster=test_cluster_name,
            instanceIdentityDocument=instance_id_document
        )
        container_instances = self.ecs_client.list_container_instances(cluster=test_cluster_name)
        container_instance_id = container_instances['containerInstanceArns'][0].split('/')[-1]
        return cluster, service, task_definition, container_instance_id

    def start_task(self, container_instance_id):
        test_cluster_name = self.cluster['cluster']['clusterName']
        self.ecs_client.start_task(
            cluster=test_cluster_name,
            taskDefinition='test_ecs_task',
            overrides={},
            containerInstances=[container_instance_id],
            startedBy='moto'
        )

    def setup_elb_resources(self):
        # Sets up a ELB resource with security groups
        security_group = self.ec2_client.create_security_group(GroupName='a-security-group', Description='First One')
        vpc = self.ec2_client.create_vpc(CidrBlock='172.28.7.0/24', InstanceTenancy='default')
        subnet1 = self.ec2_client.create_subnet(
            VpcId=vpc.id,
            CidrBlock='172.28.7.192/26',
            AvailabilityZone='us-east-1a')
        subnet2 = self.ec2_client.create_subnet(
            VpcId=vpc.id,
            CidrBlock='172.28.7.192/26',
            AvailabilityZone='us-east-1b')
        response = self.elb_client.create_load_balancer(
            Name='my-lb',
            Subnets=[subnet1.id, subnet2.id],
            SecurityGroups=[security_group.id],
            Scheme='internal',
            Type=self.get_loadbalancer_type(),
            Tags=[{'Key': 'key_name', 'Value': 'a_value'}])
        load_balancer = response['LoadBalancers'][0]
        response = self.elb_client.create_target_group(
            Name='a-target',
            Protocol='HTTP',
            Port=8080,
            VpcId=vpc.id,
            HealthCheckProtocol='HTTP',
            HealthCheckPort='8080',
            HealthCheckPath='/',
            HealthCheckIntervalSeconds=5,
            HealthCheckTimeoutSeconds=5,
            HealthyThresholdCount=5,
            UnhealthyThresholdCount=2,
            Matcher={'HttpCode': '200'})
        target_group = response['TargetGroups'][0]
        return load_balancer, target_group

    def get_loadbalancer_type(self):
        """
        Overridden by child classes to return the loadbalancer type to test.
        """
        raise NotImplementedError

    def test_check_ecs_service_deployment_daemon_service_check_verifies_task_on_all_instances(self):
        # add another instance to the ecs cluster
        test_cluster_name = self.cluster['cluster']['clusterName']
        test_instance = self.ec2_client.create_instances(
            ImageId="ami-1234abcd",
            MinCount=1,
            MaxCount=1,
        )[0]
        instance_id_document = json.dumps(
            ec2_utils.generate_instance_identity_document(test_instance)
        )
        response = self.ecs_client.register_container_instance(
            cluster=test_cluster_name,
            instanceIdentityDocument=instance_id_document
        )
        new_container_instance_id = response['containerInstance']['containerInstanceArn'].split('/')[-1]

        ecs_deploy_checker = checker.ECSDeployDaemonServiceChecker(
            'us-east-1',
            self.cluster['cluster']['clusterArn'],
            self.service['service']['serviceArn'],
            self.task_definition['taskDefinition']['taskDefinitionArn'],
            10,
            1,
        )

        # Verify daemon check fails because task is not running on one of the instances
        self.assertFalse(ecs_deploy_checker.check_daemon_service_is_fully_deployed())

        # Start task on old instance and verify check still fails
        self.start_task(self.container_instance_id)
        self.assertFalse(ecs_deploy_checker.check_daemon_service_is_fully_deployed())

        # Now start task on the new instance and verify check passes
        self.start_task(new_container_instance_id)
        self.assertTrue(ecs_deploy_checker.check_daemon_service_is_fully_deployed())

    def test_check_ecs_service_deployment_verifies_active_task_matches(self):
        ecs_deploy_checker = checker.ECSDeployActiveTasksChecker(
            'us-east-1',
            self.cluster['cluster']['clusterArn'],
            self.service['service']['serviceArn'],
            'fake_task',
            10,
            1,
        )

        # Verify for a random task definition, the check returns false
        self.assertFalse(ecs_deploy_checker.check_task_is_active())

        # ... then verify for the correct task definition, it returns true
        ecs_deploy_checker.ecs_task_definition_arn = self.task_definition['taskDefinition']['taskDefinitionArn']
        self.assertTrue(ecs_deploy_checker.check_task_is_active())


    def test_check_ecs_service_deployment_verifies_loadbalancer_health(self):
        ecs_deploy_checker = checker.ECSDeployLoadbalancerChecker(
            'us-east-1',
            self.cluster['cluster']['clusterArn'],
            self.service['service']['serviceArn'],
            self.task_definition['taskDefinition']['taskDefinitionArn'],
            10,
            1,
        )

        # Verify when load balancer is healthy, the check is healthy
        self.assertTrue(ecs_deploy_checker.check_task_is_healthy())

    def test_check_ecs_service_deployment_verifies_required_number_of_active_tasks(self):
        ecs_deploy_checker = checker.ECSDeployActiveTasksChecker(
            'us-east-1',
            self.cluster['cluster']['clusterArn'],
            self.service['service']['serviceArn'],
            self.task_definition['taskDefinition']['taskDefinitionArn'],
            10,
            2,
        )

        # Verify that it fails when there is only one task active
        self.assertFalse(ecs_deploy_checker.check_task_is_active())

        # ... then schedule another task and verify that the check now passes
        self.start_task(self.container_instance_id)
        self.assertTrue(ecs_deploy_checker.check_task_is_active())

        # ... and that it still works even if there is more than expected
        self.start_task(self.container_instance_id)
        self.assertTrue(ecs_deploy_checker.check_task_is_active())


class CheckECSServiceDeploymentALBTestCase(CheckECSServiceDeploymentTestCaseMixin, unittest.TestCase):
    def get_loadbalancer_type(self):
        return 'application'


class CheckECSServiceDeploymentNLBTestCase(CheckECSServiceDeploymentTestCaseMixin, unittest.TestCase):
    def get_loadbalancer_type(self):
        return 'network'
