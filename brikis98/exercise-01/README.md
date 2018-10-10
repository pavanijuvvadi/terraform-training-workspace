# Exercise 01

Deploy an EC2 Instance that:

1. Runs an Ubuntu AMI
1. Output its public IP
1. Responds to HTTP requests on port 8080 with the text “Hello, World”




## Hint: how to run a web server

For this exercise, we want to keep the web server as simple as possible so we can execute it directly from User Data.
Check out the [Big list of http static server one-liners](https://gist.github.com/willurd/5720255) for some easy ways
to fire up a web server.

On Ubuntu, the following works very well:

```bash
#!/bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &
```

The code above will run a simple web server that listens on port 8080 and returns the text "Hello, World."
 



## Hint: how to find an Ubuntu AMI

Use the [aws_ami data source](https://www.terraform.io/docs/providers/aws/d/ami.html) to automatically find the latest 
Ubuntu AMI as follows:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}
```