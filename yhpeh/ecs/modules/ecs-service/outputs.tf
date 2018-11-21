output "service_iam_role_name" {
  # Use a RegEx (https://www.terraform.io/docs/configuration/interpolation.html#replace_string_search_replace_) that 
  # takes a value like "arn:aws:iam::123456789012:role/S3Access" and looks for the string after the last "/".
  value = "${replace(element(concat(aws_iam_role.ecs_service_role.*.arn, list("")), 0),"/.*/+(.*)/", "$1")}"
}

output "service_iam_role_arn" {
  value = "${element(concat(aws_iam_role.ecs_service_role.*.arn, list("")), 0)}"
}

output "service_autoscaling_iam_role_arn" {
  # We use the fancy element(concat()) functions because this aws_iam_role resource may not exist.
  value = "${element(concat(aws_iam_role.ecs_service_autoscaling_role.*.arn, list("")), 0)}"
}

output "service_arn" {
  value = "${local.ecs_service_arn}"
}

output "canary_service_arn" {
  value = "${local.ecs_service_canary_arn}"
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
