#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


#
# For best practice,
# then the app should take it from the env variable
#
# OR: from API call
#


echo "Hello, World from ${name} instance $(hostname)" > index.html
nohup busybox httpd -f -p ${port} &
