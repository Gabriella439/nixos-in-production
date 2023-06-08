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
$ nix run 'github:NixOS/nixpkgs/22.11#awscli' -- configure --profile nixos-in-production
AWS Access Key ID [None]: …
AWS Secret Access Key [None]: …
Default region name [None]: …
Default output format [None]: 
```

If you're not sure what region to use, pick the one closest to you based on
the list of [AWS service endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html).

## A minimal Terraform specification

Now run the following command to bootstrap our first Terraform project:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.4#terraform'
```

… which will generate the following files:

- `module.nix` + `www/index.html`

  The NixOS configuration for our TODO list web application, except adapted to run on AWS instead of inside of a `qemu` VM.


- `flake.nix`

  A Nix flake that wraps our NixOS configuration so that we can refer to the configuration using a flake URI.


- `main.tf`

  The Terraform specification for deploying our NixOS configuration to AWS.

- `backend/main.tf`

  This Terraform configuration provisions an S3 bucket for use with Terraform's [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3).  We won't use this until the very end of this chapter, though, so we'll ignore it for now.

## Deploying our configuration

To deploy the Terraform configuration, run the following commands:

```bash
$ nix shell 'github:NixOS/nixpkgs/22.11#terraform'
$ terraform init
$ terraform apply
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

## Cleaning up

Once you verify that everything works you can destroy all deployed resources by running:

```bash
$ terraform apply -destroy
```

`terraform` will prompt you for the same information (i.e. the same region) and also prompt for confirmation just like before:

```
var.region
  Enter a value: …

…

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

… and once you confirm then `terraform` will destroy everything:

```
…

Apply complete! Resources: 0 added, 0 changed, 7 destroyed.
```

Now you can read the rest of this chapter in peace knowing that you are no longer being billed for this example.

## Terraform walkthrough

The key file in our Terraform project is `main.tf` containing the Terraform logic for how to deploy our TODO list application.

You can think of a Terraform module as being sort of like a function with side effects, meaning:

- The function has inputs

  Terraform calls these [input variables](https://developer.hashicorp.com/terraform/language/values/variables).


- The function has outputs

  Terraform calls these [output values](https://developer.hashicorp.com/terraform/language/values/outputs).


- The function does things other than producing output values

  For example, the function might provision a [resource](https://developer.hashicorp.com/terraform/language/resources/syntax).


- You can invoke another terraform module like a function call

  In other words, one Terraform module can call another Terraform module by supplying the [child module](https://developer.hashicorp.com/terraform/language/modules/syntax#calling-a-child-module) with appropriate function arguments.

Our starting `main.tf` file provides examples of all of the above concepts.

### Input variables

For example, the beginning of the module declares one input variable:

```hcl
variable "region" {
  type = string
  nullable = false
}
```

… which is analogous to a Nix function like this one that takes the following attribute set as an input:

```nix
{ region }:
  …
```

When you run `terraform apply` you will be automatically prompted to supply all input variables:

```bash
$ terraform apply
var.region
  Enter a value: …
```

… but you can also provide the same values on the command line, too, if you don't want to supply them interactively:

```bash
$ terraform apply -var region=…
```

… and if you really want to make the whole command non-interactive you can also add the `-auto-approve` flag:

```bash
$ terraform apply -var region=… -auto-approve
```

… so that you don't have to manually confirm the deployment by entering "yes".

### Output variables

The end of the Terraform module declares one output value:

```hcl
output "public_dns" {
  value = aws_instance.todo.public_dns
}
```

… which would be like our function returning an attribute set with one attribute:

```nix
{ region }:

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

In between the input variables and the output values the Terraform module declares several resources.  For now, we'll highlight the resource that provisions the EC2 instance:

```hcl
resource "aws_security_group" "todo" {
  …
}

resource "tls_private_key" "nixos-in-production" {
  …
}

resource "local_sensitive_file" "ssh_key_file" {
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
{ region }:

let
  …;

  aws_security_group.todo = aws_security_group { … };

  tls_private_key.nixos-in-production = tls_private_key { … };

  local_sensitive_file.ssh_key_file = ssh_key_file { … };

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

Our Terraform deployment declares six resources, the first of which declares a security group (basically like a firewall):

```hcl
resource "aws_security_group" "todo" {
  # The "nixos" Terraform module requires SSH access to the machine to deploy
  # our desired NixOS configuration.
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
  }

  # We will be building our NixOS configuration on the target machine, so we
  # permit all outbound connections so that the build can download any missing
  # dependencies.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  # We need to open port 80 so that we can view our TODO list web page.
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
```

The next three resources generate an SSH key pair that we'll use to manage the machine:

```hcl
# Generate an SSH key pair as strings stored in Terraform state
resource "tls_private_key" "nixos-in-production" {
  algorithm = "ED25519"
}

# Synchronize the SSH private key to a local file that the "nixos" module can
# use
resource "local_sensitive_file" "ssh_key_file" {
    filename = "${path.module}/id_ed25519"
    content = tls_private_key.nixos-in-production.private_key_openssh
}

# Mirror the SSH public key to EC2 so that we can later install the public key
# as an authorized key for our server
resource "aws_key_pair" "nixos-in-production" {
  public_key = tls_private_key.nixos-in-production.public_key_openssh
}
```

{blurb, class: warning}
The [`tls_private_key` resource](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) is currently not secure because the deployment state is stored locally unencrypted.  We will fix this later on in this chapter by storing the deployment state using Terraform's [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3).
{/blurb}

After that we get to the actual server:

```hcl
resource "aws_instance" "todo" {
  # This will be an AMI for a stock NixOS server which we'll get to below.
  ami = module.ami.ami

  # We could use a smaller instance size, but at the time of this writing the
  # t3.micro instance type is available for 750 hours under the AWS free tier.
  instance_type = "t3.micro"

  # Install the security groups we defined earlier
  security_groups = [ aws_security_group.todo.name ]

  # Install our SSH public key as an authorized key
  key_name = aws_key_pair.nixos-in-production.key_name

  # Request a bit more space because we will be building on the machine
  root_block_device {
    volume_size = 7
  }
}
```

Finally, we declare a resource whose sole purpose is to wait until the EC2 instance is reachable via SSH so that the "nixos" module knows how long to wait before deploying the NixOS configuration:

```hcl
# This ensures that the instance is reachable via `ssh` before we deploy NixOS
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      host = aws_instance.todo.public_dns
      private_key = tls_private_key.nixos-in-production.private_key_openssh
    }

    inline = [ ":" ]  # Do nothing; we're just testing SSH connectivity
  }
}
```

### Modules

Our Terraform module also invokes two other Terraform modules (which I'll refer to as "child modules") and we'll highlight here the module that deploys the NixOS configuration:

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

You can liken child modules to Nix function calls for imported functions:

```nix
{ region }:

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

  tls_private_key.nixos-in-production = tls_private_key { … };

  local_sensitive_file.ssh_key_file = ssh_key_file { … };

  aws_key_pair.nixos-in-production = aws_key_pair { … };

  aws_instance.todo = aws_instance { … };

  null_resource.wait = null_resource { … };

in
  { output = aws_instance.todo.public_dns; }
```

The first child module selects the correct NixOS AMI to use:

```hcl
module "ami" {
  source = "github.com/Gabriella439/terraform-nixos-ng//ami?ref=d8563d06cc65bc699ffbf1ab8d692b1343ecd927"
  release = "22.11"
  region = var.region
  system = "x86_64-linux"
}
```

… and the second child module deploys our NixOS configuration to our EC2 instance:

```hcl
module "nixos" {
  source = "github.com/Gabriella439/terraform-nixos-ng//nixos?ref=d8563d06cc65bc699ffbf1ab8d692b1343ecd927"

  host = "root@${aws_instance.todo.public_ip}"

  # Get the NixOS Configuration from the nixosConfigurations.default attribute
  # of our flake.nix file
  flake = ".#default"

  # Build our NixOS configuration on the same machine that we're deploying to
  arguments = [ "--build-host", "root@${aws_instance.todo.public_ip}" ]

  ssh_options = "-o StrictHostKeyChecking=accept-new -i ${local_sensitive_file.ssh_key_file.filename}"

  depends_on = [ null_resource.wait ]
}
```

{blurb, class:information}
In this example we build our NixOS configuration on our web server so that this example can be deployed without any supporting infrastructure.  However, you typically will want to build the NixOS configuration on a dedicated builder rather than building on the target server for two reasons:

- You can deploy to a smaller/leaner server

  Building a NixOS system typically requires more disk space, RAM, and network bandwidth than running/deploying the same system.  Centralizing that build work onto a larger special-purpose builder helps keep other machines lightweight.


- You can lock down permissions on the target server

  For example, if we didn't have to build on our web server then we wouldn't need to permit outbound connections on that server since it would no longer need to fetch build-time dependencies.

The next chapter will cover how to provision a dedicated builder for this purpose.
{/blurb}

## S3 Backend

The above Terraform deployment doesn't properly protect the key pair used to `ssh` into and manage the NixOS machine.  By default the private key of the key pair is stored in a world-readable `terraform.tfstate` file.  However, even if we were to restrict that file's permissions we wouldn't be able to easily share our Terraform deployment with colleagues.  In particular, we wouldn't want to add the `terraform.tfstate` file to version control in a shared repository since it contains sensitive secrets.

The good news is that we can fix both of those problems by setting up an [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) for Terraform which allows the secret to be securely stored in an S3 bucket that can be shared by multiple people managing the same Terraform deployment.

The template for this chapter's Terraform configuration already comes with a `backend/` subdirectory containing a Terraform specification that provisions a suitable S3 bucket and DynamoDB table for an S3 backend.  All you have to do is run:

```bash
$ cd ./backend
$ terraform apply
var.region
  Enter a value: …

…

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Just make sure to use the same region as our original Terraform deployment when prompted.

When the deployment succeeds it will output the name of the randomly-generated S3 bucket, which will look something like this (with a timestamp in place of the `X`s):

```
…
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

bucket = "nixos-in-productionXXXXXXXXXXXXXXXXXXXXXXXXXX"
```

Then switch back to the original Terraform deployment in the parent directory:

```bash
$ cd ..
```

… and modify that deployment's `main.tf`  to reference the newly-created `bucket` like this:

```hcl
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.56"
    }
  }

  # This is the new bit you want to add
  backend "s3" {
    bucket = "nixos-in-productionXXXXXXXXXXXXXXXXXXXXXXXXXX"
    key = "terraform"
    region = "…"  # Use the same region here that you used before
    dynamodb_table = "terraform-state"
    profile = "nixos-in-production"
  }
}
```

{blurb, class:information}
These last few manual steps to update the S3 backend are a bit gross but this is primarily to work around limitations in Terraform.  In particular, Terraform doesn't provide a way for our main deployment to automatically reference the S3 backend we created.  Terraform specifically prohibits `backend` stanzas from referencing variables so all of the backend options have to be hard-coded values.
{/blurb}

Then you can upgrade your existing deployment to reference the S3 backend you just provisioned by re-running `terraform init` with the `-migrate-state` option:

```bash
$ terraform init -migrate-state
Initializing modules...

Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes
```

… and once that's done you can verify that nothing broke by running `terraform apply` again, which should report that no new changes need to be deployed:

```bash
$ terraform apply
var.region
  Enter a value: …

…

No changes. Your infrastructure matches the configuration.
```

The difference is that now the terraform state is securely stored in an S3 bucket instead of on your filesystem so you'd now be able to store your Terraform configuration in version control and let other developers manage the same deployment.  There's just one last thing you need to do, which is to remove the `terraform.tfstate.backup` file, which contains the old (pre-S3-backend) Terraform state, including the secrets:

```bash
$ rm terraform.tfstate.backup
```

You can also remove the `terraform.tfstate` file, too, since it's empty and no longer used:

```bash
$ rm terraform.tfstate
```

{blurb, class:information}
Future Terraform examples in this book won't include the S3 backend code to keep them shorter, but feel free to reuse the same S3 bucket created in this chapter to upgrade any of those examples with an S3 backend.  However, if you do keep in mind that you need to use a different key for storing Terraform's state if you want to keep those examples separate.

In other words, when adding the S3 backend to the `terraform` clause, specify a different key for each separate deployment:

```hcl
terraform {
  …

  backend "s3" {
    …
    key = "…"  # This is what needs to be unique per deployment
    …
  }
}
```
{/blurb}

This key is used by Terraform to record where to store the deployment's state within the S3 bucket, so if you use the same key for two different deployments they will will interfere with one another.

## Version control

Once you create the S3 backend you can safely store your Terraform configuration in version control.  Specifically, these are the files that you want to store in version control:

- `flake.nix` / `module.nix` / `www/`

  These provide the configuration for the machine we're deploying so we obviously need to keep these.


- `flake.lock`

  It's also worth keeping this in version control even though it's not strictly necessary.  The lock file slightly improves the determinism of the deployment, although the flake included in the template is already fairly deterministic even without the lockfile because it references a specific tag from Nixpkgs.


- `main.tf` / `backend/main.tf`

  We definitely want to keep the Terraform deployments for our main deployment and the S3 backend.


- `terraform.tfstate`

  You don't need to keep this in version control (it's an empty file

Just as important, you do **NOT** want to keep the `id_ed25519` file in version control (since this contains the private key).  In fact, the provided template includes a `.gitignore` file to prevent you from accidentally adding the private key to version control.

Terraform will recreate this private key file locally for each developer that manages the deployment.  For example, if another developer were to apply the deployment for the first time, they would see this diff:

```bash
Terraform will perform the following actions:

  # local_sensitive_file.ssh_key_file will be created
  + resource "local_sensitive_file" "ssh_key_file" {
      + content              = (sensitive value)
      + directory_permission = "0700"
      + file_permission      = "0700"
      + filename             = "./id_ed25519"
      + id                   = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

… indicating that Terraform will download the private key from the S3 backend and create a secure local copy in order to `ssh` into the machine.
