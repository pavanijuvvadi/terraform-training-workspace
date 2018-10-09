# Exercise 04b

1. Deploy an ALB that listens on port 80
1. The ALB should distributes traffic across the ASG
1. Output the ALB DNS name
1. Submit a PR




## Hint: ALB resources

Creating an ALB requires using *four* different resources:

1. [aws_alb](https://www.terraform.io/docs/providers/aws/r/alb.html): The ALB itself. Configure it to use the same
   default subnets you used for the ASG.

1. [aws_alb_target_group](https://www.terraform.io/docs/providers/aws/r/alb_target_group.html): Your ASG should
   register all the EC2 Instances in this Target Group at port 8080. Make sure to enable health checks too!

1. [aws_alb_listener](https://www.terraform.io/docs/providers/aws/r/alb_listener.html): This is where you tell the
   ALB to listen on port 80. Note that as part of the listener definition, you'll have to specify a "default action,"
   which is what the ALB should do if nothing matches an incoming request. You should set this to forward to your
   ASG target group.

1. [aws_alb_listener_rule](https://www.terraform.io/docs/providers/aws/r/alb_listener_rule.html): For each listener
   you add using `aws_alb_listener`, you can specify one or more rules that specify which paths or domain names should
   be routed to which target groups. To keep the exercise simple, you should add a single `aws_alb_listener_rule` that
   sends all traffic (`path-pattern` of `*`) to the ASG Target Group.



## Hint: ALB security group

The ALB needs its own security group! Make sure to allow:
 
* Inbound connections on port 80. This allows incoming HTTP requests.

* All outbound connections. This allows the ALB to perform health checks.




## Hint: ASG and ALB integration

You should configure the ASG to: 

1. Automatically register Instances with the ALB. See the `target_group_arns` parameter.
1. Use the ALB's health check. See the `health_check_type` parameter.