from setuptools import setup, find_packages


setup(
    name='ecs_service_deployment_checker',
    version='0.1.0',
    packages=find_packages(exclude=["tests"]),
    entry_points={
        'console_scripts': [
            'check_ecs_service_deployment = check_ecs_service_deployment.main:check_ecs_service_deployment'
        ]
    },
    test_suite="tests",
)
