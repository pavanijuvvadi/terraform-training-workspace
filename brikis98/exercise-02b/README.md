# Exercise 02b

1. Find a partner
1. Modify their web server code to say something other than "Hello, World"
1. Deploy the changes
1. Submit a PR




## Hint: use the docs!

For this exercise, I won't show you the Terraform code ahead of time. You'll have to use the [Terraform AWS 
docs](https://www.terraform.io/docs/providers/aws/index.html) to figure out how to create S3 buckets and DynamoDB
tables.

Get used to reading and navigating these docs!




## A note on deployment

When you change the User Data on an EC2 Instance and run `terraform apply`, notice how the redeploy works: the old
EC2 instance is first terminated and then the new EC2 instance is started. What would happen if this server was hosting
a user-facing application?