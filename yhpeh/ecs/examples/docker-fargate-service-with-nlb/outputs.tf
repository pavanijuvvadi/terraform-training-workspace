output "http_port" {
  value = "${var.http_port}"
}

output "service_dns_name" {
  value = "${var.service_name}.${data.aws_route53_zone.sample.name}"
}

output "nlb_dns_name" {
  value = "${module.nlb.nlb_dns_name}"
}

output "tcp_listener_arns" {
  value = "${merge(module.nlb.tcp_listener_arns, map(aws_lb_listener.example.port, aws_lb_listener.example.arn))}"
}
