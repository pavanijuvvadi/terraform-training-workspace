#!/bin/bash


#
# For best practice,
# then the app should take it from the env variable
#
# OR: from API call
#


echo "Hello, World from ${name} instance $(hostname)" > index.html
nohup busybox httpd -f -p ${port} &
