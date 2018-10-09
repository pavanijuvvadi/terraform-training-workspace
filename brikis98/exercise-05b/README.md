# Exercise 05b

1. Update the microservice module to support two User Data scripts: one that returns HTML, one that returns JSON
1. Deploy two microservices: a frontend that returns HTML and a backend that returns JSON
1. Bonus: update the frontend to make service calls to the backend via the backend's ALB
1. Submit a PR




## Hint: User Data best practices

Here are a few best practices for working with User Data scripts:

1. Always put `#!/bin/bash` as the very first line.

1. To help with debugging, we recommend sending the User Data log output to user-data.log, syslog, and the console. You
   can do this with the following one-liner at the top of our script:

    ```bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    ```

1. Put the User Data script in a separate file (e.g. `user-data.sh`) and load it using the [file interplation 
   function](https://www.terraform.io/docs/configuration/interpolation.html#file-path-)
   and a [template_file data source](https://www.terraform.io/docs/providers/template/d/file.html).
   

   
   
## Hint: module file paths
   
If you are trying to access a file from within a module, relative paths may not work as you expect. Therefore, always
use one of the [path helpers](https://www.terraform.io/docs/configuration/interpolation.html#path-information) in your 
path, with `path.module` being the most useful:

```hcl
template = "${file("${path.module}/user-data.sh")}"
```
   



## Hint: making service calls

If you want the frontend to make service calls, using a static web server will no longer do it. You now need a real
web framework of some sort. A particularly easy one to install and use is [Sinatra](http://www.sinatrarb.com/):

```bash
sudo apt-get install -y ruby
sudo gem install sinatra --no-rdoc --no-ri

cat << EOF > app.rb
require 'sinatra'

set :port, 8080
set :bind, '0.0.0.0'

get '/' do
  "Hello, World"
end
EOF

ruby app.rb
```