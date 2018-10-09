# Exercise 02a

1. Create an S3 bucket with versioning
1. Create a DynamoDB table
1. Configure S3 as a backend for exercise 01 and exercise 02




## Hint: chicken-and-egg

There is a bit of a chicken-and-egg with using Terraform to create the S3 bucket that Terraform itself will use as a
backend. You have to create the code for the S3 bucket (and corresponding DynamoDB table), run `apply`, and only then
add the backend configuration that uses that S3 bucket and DynamoDB table.