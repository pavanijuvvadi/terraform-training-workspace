# About this Dockerfile
#
# This Dockerfile was optimized to have the smallest possible Docker image size, which would make running tests faster.
# Note that you may not always want to make image size your top priority. For example, Alpine Linux is famously small
# and also famously irritating when it comes to package management. What you save in time downloading a larger image
# may be dwarfed by the additional developer time spent dealing with Alpine's edge cases.
#
# As an alternative, consider using an official Docker node image that's not based on Alpine Linux (e.g. node:7.3.0), or
# a base image of ubuntu:16.04 and installing nodejs via apt.

FROM node:7.3.0-alpine

## Install the latest version of the AWS CLI, which the Node.js app will use to download files from S3. This is done to
## verify that ECS Task IAM Roles work.
RUN apk --update upgrade && \
    apk add curl ca-certificates python py-pip && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/* && \
    pip install awscli

COPY server.js /app/server.js

EXPOSE 3000

# Note: we have to use this form of CMD rather than the array version or CTRL+C doesn't work.
CMD node /app/server.js