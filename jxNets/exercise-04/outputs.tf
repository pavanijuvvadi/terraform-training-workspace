output "elb_dns_name" {
  value = "${aws_elb.web_servers.dns_name}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.web_servers.name}"
}