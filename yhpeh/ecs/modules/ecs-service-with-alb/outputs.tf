output "ecs_service_arn" {
  value = "${local.ecs_service_arn}"
}

output "ecs_service_name" {
  value = "${element(concat(aws_ecs_service.service_with_auto_scaling.*.name, aws_ecs_service.service_without_auto_scaling.*.name), 0)}"
}

output "ecs_service_canary_arn" {
  value = "${local.ecs_service_canary_arn}"
}

output "ecs_service_autoscaling_role_arn" {
  # We use the fancy element(concat()) functions because this aws_iam_role resource may not exist.
  value = "${element(concat(aws_iam_role.ecs_service_autoscaling_role.*.arn, list("")), 0)}"
}

output "ecs_service_autoscaling_role_name" {
  # We use the fancy element(concat()) functions because this aws_iam_role resource may not exist.
  value = "${element(concat(aws_iam_role.ecs_service_autoscaling_role.*.name, list("")), 0)}"
}

output "ecs_service_app_autoscaling_target_arn" {
  # We use the fancy element(concat()) functions because this aws_appautoscaling_target resource may not exist.
  value = "${element(concat(aws_appautoscaling_target.appautoscaling_target.*.role_arn, list("")), 0)}"
}

output "ecs_task_iam_role_name" {
  value = "${aws_iam_role.ecs_task.name}"
}

output "ecs_task_iam_role_arn" {
  value = "${aws_iam_role.ecs_task.arn}"
}

output "aws_ecs_task_definition_arn" {
  value = "${aws_ecs_task_definition.task.arn}"
}

output "aws_ecs_task_definition_canary_arn" {
  value = "${
    element(
      concat(
        aws_ecs_task_definition.task_canary.*.arn,
        list("")
      ),
      0
    )
  }"
}

output "target_group_name" {
  value = "${element(concat(aws_alb_target_group.ecs_service_without_sticky_sessions.*.name, aws_alb_target_group.ecs_service_with_sticky_sessions.*.name, list("")), 0)}"
}

output "target_group_arn" {
  value = "${element(concat(aws_alb_target_group.ecs_service_without_sticky_sessions.*.arn, aws_alb_target_group.ecs_service_with_sticky_sessions.*.arn, list("")), 0)}"
}
