# Exercise 07

1. Use Packer to build an AMI for the frontend with a web framework installed
1. Deploy the AMI as your frontend, updating the frontend User Data script accordingly
1. Submit a PR




## Hint: finding an Ubuntu AMI as a base

When building AMIs with Packer, you have to specify some AMI to use as the *source*. You can hard-code the source AMI 
ID using the [source_ami](https://www.packer.io/docs/builders/amazon-ebs.html#source_ami) parameter or, you can have 
Packer find the AMI ID automatically using the [source_ami_filter](https://www.packer.io/docs/builders/amazon-ebs.html#source_ami_filter)
parameter. For example, here is how you can have Packer use the latest version of Ubuntu 16.04 as the source AMI:

```json
{
  "builders": [{
    "ami_name": "iac-workshop-sample-frontend-{{isotime | clean_ami_name}}",
    "instance_type": "t2.micro",
    "region": "us-east-1",
    "type": "amazon-ebs",
    "ssh_username": "ubuntu",
    "source_ami_filter": {
      "filters": {
        "virtualization-type": "hvm",
        "architecture": "x86_64",
        "name": "*ubuntu-xenial-16.04-amd64-server-*",
        "block-device-mapping.volume-type": "gp2",
        "root-device-type": "ebs"
      },
      "owners": ["099720109477"],
      "most_recent": true
    }
  }]
}
```




## Hint: a simple web server 

A particularly simple web framework to install and use on Ubuntu is [Sinatra](http://www.sinatrarb.com/):

```bash
sudo apt-get update
sudo apt-get install -y ruby
sudo gem install sinatra --no-rdoc --no-ri
```

Once installed, here is all it takes to create a simple web app that responds with "Hello, World":

```ruby
require 'sinatra'

get '/' do
  'Hello, World'
end
```

Note that you typically also want to tell Sinatra what port and IP to listen on, so the full example looks more like 
this:

```ruby
require 'sinatra'

set :port, 8080
set :bind, '0.0.0.0'

get '/' do
  'Hello, World'
end
```




## Hint: pause_before

The OS may take some time to boot, so you may want to use `pause_before` to wait a little while before executing your 
first provisioner:

```json
{
  "provisioners": [{
    "type": "shell",
    "pause_before": "30s",
    "script": "{{template_dir}}/configure-backend.sh"
  }]
}
```