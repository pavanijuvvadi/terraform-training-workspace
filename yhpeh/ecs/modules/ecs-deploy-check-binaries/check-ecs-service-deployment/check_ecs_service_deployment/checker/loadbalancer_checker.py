from .. import utils
from .base import ECSDeployCheckerBase


class ECSDeployLoadbalancerChecker(ECSDeployCheckerBase):
    def run(self):
        """
        Execute check for loadbalancer healthchecks, validating that they are
        passing for the deployed service.

        Returns:
            A tuple pair of boolean and string, where the boolean indicates
            whether or not the check passed, and the string represents an error
            reason if it failed.
        """
        utils.logger.info('Checking whether or not task is returning a healthy status')
        passed = self.check_until_consecutive_successes(self.check_task_is_healthy)
        if not passed:
            utils.logger.info('ECS deployment check timedout waiting for task to be healthy')
            return False, 'Timedout waiting for task to be healthy'

        utils.logger.info('Passed loadbalancer check')
        return True, ''

    def check_task_is_healthy(self):
        """
        Verify that the deployed task is passing loadbalancer health checks on
        all targets.
        """
        service = self.get_service()
        loadbalancers = service['loadBalancers']
        utils.logger.info(
            'Found {} loadbalancers for service {}'.format(len(loadbalancers), self.ecs_service_arn))
        return all(
            self.check_loadbalancer_target(loadbalancer['targetGroupArn'])
            for loadbalancer in loadbalancers)

    def check_loadbalancer_target(self, target_group_arn):
        """
        Verify the given loadbalancer target is passing all healthchecks.
        """
        targets = self.elb_client.describe_target_health(TargetGroupArn=target_group_arn)
        utils.logger.info(
            'Found {} targets for target group {}'.format(len(targets), target_group_arn))
        return all(
            state['TargetHealth']['State'] == 'healthy'
            for state in targets['TargetHealthDescriptions'])
