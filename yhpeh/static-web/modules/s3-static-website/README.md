# S3 Static Website

This Terraform Module creates an [AWS S3](https://aws.amazon.com/s3/) bucket that can be used to host a [static
website](http://docs.aws.amazon.com/AmazonS3/latest/dev/WebsiteHosting.html). That is, the website can contain static
HTML, CSS, JS, and images. This module allows you to specify custom routing rules for the website and optionally, 
create a custom domain name for it. 

The reason to serve static content from S3 rather than from your own app server is that it can significantly reduce the
load on your server, allowing it to solely focus on serving dynamic data. This will save you money and make your 
website run faster. For even bigger improvements in performance, consider deploying a CloudFront Content Distribution 
Network (CDN) in front of the S3 bucket using the [s3-cloudfront module](/modules/s3-cloudfront). 
 




## Quick Start

* See the [s3-static-website example](/examples/s3-static-website) for working sample code.
* Check out [vars.tf](vars.tf) for all parameters you can set for this module.





## How do I test my website?

This module outputs the domain name of your website using the `website_domain_name` output variable.

By default, the domain name will be of the form:

```
<BUCKET_NAME>.s3-website-<AWS_REGION>.amazonaws.com/
```

Where `BUCKET_NAME` is the name you specified for the bucket and `AWS_REGION` is the region you created the bucket in.
For example, if the bucket was called `foo` and you deployed it in `us-east-1`, the URL would be:

```
foo.s3-website-us-east-1.amazonaws.com
```

If you set `var.create_route53_entry` to true, then this module will create a DNS A record in [Route 
53](https://aws.amazon.com/route53/) for your S3 bucket with the domain name in `var.website_domain_name`, and you will 
be able to use that custom domain name to access your bucket instead of the `amazonaws.com` domain.





## How do I configure HTTPS (SSL) or a CDN?

By default, the static content in an S3 bucket is only accessible over HTTP. To be able to access it over HTTPS, you
need to deploy a CloudFront distribution in front of the S3 bucket. This will also act as a Content Distribution
Network (CDN), which will reduce latency for your users. You will need to set the `use_with_cloudfront` parameter to
`true`.

To set up a CloudFront distribution, see the [s3-cloudfront module](/modules/s3-cloudfront).
 




## How do I handle www + root domains?

If you are using your S3 bucket for both the `www.` and root domain of a website (e.g. `www.foo.com` and `foo.com`),
you need to create two buckets. One of the buckets contains the actual static content. The other sets the 
`should_redirect_all_requests` parameter to `true` and sets the `redirect_all_requests_to` parameter to the URL of the
first site. See the [Setting Up a Static Website Using a Custom 
Domain](http://docs.aws.amazon.com/AmazonS3/latest/dev/website-hosting-custom-domain-walkthrough.html) documentation
for more info.
