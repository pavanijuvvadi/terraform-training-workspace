output "fargate_task_iam_role_id" {
  value = "${aws_iam_role.fargate_task_role.id}"
}

output "fargate_task_iam_role_name" {
  value = "${aws_iam_role.fargate_task_role.name}"
}

output "fargate_task_execution_iam_role_id" {
  value = "${aws_iam_role.fargate_task_execution_role.id}"
}

output "fargate_task_execution_iam_role_name" {
  value = "${aws_iam_role.fargate_task_execution_role.name}"
}

output "service_arn" {
  value = "${local.ecs_service_arn}"
}

output "target_group_arn" {
  value = "${element(concat(aws_lb_target_group.fargate_service.*.arn, list("")), 0)}"
}

output "fargate_instance_security_group_id" {
  value = "${aws_security_group.fargate.id}"
}
