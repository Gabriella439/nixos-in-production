# Deploying to AWS using Terraform

Up until now we've been playing things safe and test-driving everything locally on our own machine.  We could even prolong this for quite a while because NixOS has advanced support for building and testing clusters of NixOS machines locally using virtual machines.  However, at some point we need to dive in and deploy a server if we're going to use NixOS for real.

In this chapter we'll deploy our TODO app to our first "production" server in AWS meaning that you *will* need to [create an AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) to follow along.

{blurb, class:information}
AWS prices and offers will vary so this book can't provide any strong guarantees about what this would cost you.  However, at the time of this writing the examples in this chapter would fit well within the current AWS free tier, which is 750 hours of a `t3.micro` instance.

Even if there were no free tier, the cost of a `t3.micro` instance is currently ≈1¢ / hour or ≈ $7.50 / month if you never shut it off (and you can shut it off when you're not using it).  So at most this chapter should only cost you a few cents from start to finish.

Throughout this book I'll take care to minimize your expenditures by showing how you to develop and test locally as much as possible.
{/blurb}

In the spirit of Infrastructure as Code, we'll be using Terraform to declaratively provision AWS resources, but before doing so we need to generate AWS access keys for programmatic access.

## Configuring your access keys

To generate your access keys, follow the instructions in [Accessing AWS using AWS credentials](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html).

In particular, take care to **not** generate access keys for your account's root user.  Instead, use the Identity and Access Management (IAM) service to create a separate user with "Admin" privileges and generate access keys for that user.  The difference between a root user and an admin user is that an admin user's privileges can later be limited or revoked, but the root user's privileges can never be limited nor revoked.

{blurb, class:information}
The above AWS documentation also recommends generating temporary access credentials instead of long-term credentials.  However, setting this up properly and ergonomically requires setting up the IAM Identity Center which is only permitted for AWS accounts that have set up an AWS Organization.  That is way outside of the scope of this book so instead you should just generate long-term credentials for a non-root admin account.
{/blurb}

If you generated the access credentials correctly you should have:

- an access key ID (i.e. `AWS_ACCESS_KEY_ID`)
- a secret access key (i.e. `AWS_SECRET_ACCESS_KEY`)

If you haven't already, configure your development environment to use these tokens by running:

```bash
$ nix run github:NixOS/nixpkgs/22.11#awscli -- configure --profile nixos-in-production
AWS Access Key ID [None]: …
AWS Secret Access Key [None]: …
Default region name [None]: …
Default output format [None]: 
```

If you're not sure what region to use, pick the one closest to you based on
the list of [AWS service endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html).

## Generating an SSH key

You will need an SSH key pair as well.  If you don't already have one then run:

```bash
$ nix shell github:NixOS/nixpkgs/22.11#openssh --command \
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
```

## A minimal Terraform specification

Now run the following command to bootstrap our first Terraform project:

```bash
$ nix flake init --template github:Gabriella439/nixos-in-production#server
```

… which will generate the following files:

- `module.nix` + `www/index.html`

  The NixOS configuration for our TODO list web application, except adapted to run on AWS instead of inside of a `qemu` VM.


- `flake.nix`

  A Nix flake that wraps our NixOS configuration so that we can refer to the configuration using a flake URI.


- `main.tf`

  The Terraform specification for deploying our NixOS configuration to AWS.

## Deploying our configuration

To deploy the Terraform configuration, run the following commands:

```bash
$ nix shell github:NixOS/nixpkgs/22.11#terraform
$ terraform init
$ terraform apply
```

… and when prompted to enter the `private_key_file`, use the appropriate path to the private key.  If you generated the key following the instructions earlier in this chapter then you would specify:

```
var.private_key_file
  Enter a value: ~/.ssh/id_ed25519
```

… and when prompted to enter the `region`, use the same AWS region you specified earlier when running `aws configure`:

```
var.region
  Enter a value: …
```

After that, `terraform` will display the execution plan and ask you to confirm the plan:

```
module.ami.data.external.ami: Reading...
module.ami.data.external.ami: Read complete after 1s [id=-]

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

…

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

… and if you confirm then `terraform` will deploy that execution plan:

```
…

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

public_dns = "ec2-….compute.amazonaws.com"
```

The final output will include the URL for your server.  If you open that URL in your browser you will see the exact same TODO server as before, except now running on AWS instead of inside of a `qemu` virtual machine.  If this is your first time deploying something to AWS then congratulations!

## Terraform walkthrough

The main new file in our Terraform project is `main.tf` containing the Terraform logic for how to deploy our TODO list application.

You can think of a Terraform module as being sort of like a function with side effects, meaning:

- The function has inputs

  Terraform calls these [input variables](https://developer.hashicorp.com/terraform/language/values/variables).


- The function has outputs

  Terraform calls these [output values](https://developer.hashicorp.com/terraform/language/values/outputs).


- The function does things other than producing output values

  For example, the function might provision a [resource](https://developer.hashicorp.com/terraform/language/resources/syntax).


- You can invoke another terraform module like a function call

  In other words, one Terraform module can call another Terraform module by supplying the [child module](https://developer.hashicorp.com/terraform/language/modules/syntax#calling-a-child-module) with appropriate function arguments.

The `main.tf` provides examples of all of the above concepts.

### Input variables

For example, the beginning of the module declares the input variables:

```hcl
variable "private_key_file" {
  type = string
  nullable = false
}

variable "region" {
  type = string
  nullable = false
}
```

… which is analogous to a Nix function like this one that takes the following attribute set as an input:

```nix
{ private_key_file, region }:
  …
```

When you run `terraform apply` you will be automatically prompted to supply any input variables which do not have default values:

```bash
$ terraform apply
var.private_key_file
  Enter a value: …
var.region
  Enter a value: …
```

… but you can also provide the same values on the command line, too, if you want the command to be non-interactive:

```bash
$ terraform apply -var private_key_file=… -var region=…
```

### Output variables

The end of the Terraform module declares the output values:

```hcl
output "public_dns" {
  value = aws_instance.todo.public_dns
}
```

… which would be like our function returning an attribute set with one attribute:

```nix
{ private_key_file, region }:

let
  …

in
  { output = aws_instance.todo.public_dns; }
```

… and when the deploy completes Terraform will render all output values:

```
Outputs:

public_dns = "ec2-….compute.amazonaws.com"
```

### Resources

In between the input variables and the output values the Terraform module declares several resources.  For now, we'll focus on the resource that provisions the EC2 instance:

```hcl
resource "aws_security_group" "todo" {
  …
}

resource "aws_key_pair" "nixos-in-production" {
  …
}

resource "aws_instance" "todo" {
  ami = module.ami.ami
  instance_type = "t3.micro"
  security_groups = [ aws_security_group.todo.name ]
  key_name = aws_key_pair.nixos-in-production.key_name

  root_block_device {
    volume_size = 7
  }
}

resource "null_resource" "wait" {
  …
}
```

… and you can think of resources sort of like `let` bindings that provision infrastructure as a side effect:

```nix
{ private_key_file, region }:

let
  …;

  aws_security_group.todo = aws_security_group { … };

  aws_key_pair.nixos-in-production = aws_key_pair { … };

  aws_instance.todo = aws_instance {
    ami = module.ami.ami;
    instance_type = "t3.micro";
    security_groups = [ aws_security_group.todo.name ];
    key_name = aws_key_pair.nixos-in-production.key_name;
    root_block_device.volume_size = 7;
  }

  null_resource.wait = null_resource { … };

in
  { output = aws_instance.todo.public_dns; }
```

Our Terraform deployment declares four resources, the first of which declares a security group (basically like a firewall):

```hcl
resource "aws_security_group" "todo" {
  # This is needed for the "nixos" module to manage the target host
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
  }

  # This is needed since we build on the target machine so that the machine can
  # download dependencies
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This lets us access our web server
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
```

### Modules

This Terraform module also invokes two other Terraform modules and we'll focus on the module that deploys the NixOS configuration:

```hcl
module "ami" {
  …;
}

module "nixos" {
  source = "github.com/Gabriella439/terraform-nixos-ng//nixos?ref=d8563d06cc65bc699ffbf1ab8d692b1343ecd927"
  host = "root@${aws_instance.todo.public_ip}"
  flake = ".#default"
  arguments = [ "--build-host", "root@${aws_instance.todo.public_ip}" ]
  ssh_options = "-o StrictHostKeyChecking=accept-new"
  depends_on = [ null_resource.wait ]
}
```

… and you can liken those modules to function calls:


```nix
{ private_key_file, region }:

let
  module.ami = …;

  module.nixos =
    let
      source = fetchFromGitHub {
        owner = "Gabriella439";
        repo = "terraform-nixos-ng";
        rev = "d8563d06cc65bc699ffbf1ab8d692b1343ecd927";
        hash = …;
      };

    in
      import source {
        host = "root@${aws_instance.todo_public_ip}";
        flake = ".#default";
        arguments = [ "--build-host" "root@${aws_instance.todo.public_ip}" ];
        ssh_options = "-o StrictHostKeyChecking=accept-new";
        depends_on = [ null_resource.wait ];
      };

  aws_security_group.todo = aws_security_group { … };

  aws_key_pair.nixos-in-production = aws_key_pair { … };

  aws_instance.todo = aws_instance { … };

  null_resource.wait = null_resource { … };

in
  { output = aws_instance.todo.public_dns; }
```
