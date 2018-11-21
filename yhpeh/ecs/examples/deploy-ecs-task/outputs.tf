output "ecs_cluster_arn" {
  value = "${module.ecs_cluster.ecs_cluster_arn}"
}

output "ecs_cluster_name" {
  value = "${module.ecs_cluster.ecs_cluster_name}"
}

output "ecs_task_family" {
  value = "${aws_ecs_task_definition.example.family}"
}

output "ecs_task_revision" {
  value = "${aws_ecs_task_definition.example.revision}"
}

output "aws_region" {
  value = "${var.aws_region}"
}
