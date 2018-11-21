output "service_arn" {
  value = "${local.ecs_service_arn}"
}

output "aws_ecs_task_definition_arn" {
  value = "${aws_ecs_task_definition.task.arn}"
}

output "ecs_task_revision" {
  value = "${aws_ecs_task_definition.task.revision}"
}

output "ecs_service_app_autoscaling_target_arn" {
  # We use the fancy element(concat()) functions because this aws_appautoscaling_target resource may not exist.
  value = "${element(concat(aws_appautoscaling_target.appautoscaling_target.*.role_arn, list("")), 0)}"
}

output "ecs_task_security_group_id" {
  value = "${aws_security_group.ecs_task_security_group.id}"
}

output "ecs_task_iam_role_name" {
  value = "${aws_iam_role.ecs_task.name}"
}

output "ecs_task_iam_role_arn" {
  value = "${aws_iam_role.ecs_task.arn}"
}
