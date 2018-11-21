output "ecs_cluster_arn" {
  value = "${aws_ecs_cluster.ecs.id}"

  # Explicitly ties the aws_ecs_cluster to the aws_autoscaling_group, so that the resources are created together
  depends_on = ["aws_autoscaling_group.ecs"]
}

output "ecs_cluster_name" {
  value = "${aws_ecs_cluster.ecs.name}"

  # Explicitly ties the aws_ecs_cluster to the aws_autoscaling_group, so that the resources are created together
  depends_on = ["aws_autoscaling_group.ecs"]
}

output "ecs_cluster_asg_name" {
  value = "${aws_autoscaling_group.ecs.name}"
}

output "ecs_instance_security_group_id" {
  value = "${aws_security_group.ecs.id}"
}

output "ecs_instance_iam_role_arn" {
  value = "${aws_iam_role.ecs.arn}"
}

output "ecs_instance_iam_role_name" {
  # Use a RegEx (https://www.terraform.io/docs/configuration/interpolation.html#replace_string_search_replace_) that 
  # takes a value like "arn:aws:iam::123456789012:role/S3Access" and looks for the string after the last "/".
  value = "${replace(aws_iam_role.ecs.arn, "/.*/+(.*)/", "$1")}"
}
