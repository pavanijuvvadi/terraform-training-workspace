#!/bin/bash

set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# The variables below are filled in via Terraform interpolation
echo "Hello, World from ${name} running at $(hostname)!!!" > index.html
nohup busybox httpd -f -p ${port} &
