# Deploying to AWS using Terraform

Up until now we've been playing things safe and test-driving everything locally on our own machine.  We could even prolong this for quite as while because NixOS has advanced support for building and testing clusters of NixOS machines locally using virtual machines.  However, at some point we need to dive in and deploy a real server if we're going to use NixOS for real.

In this chapter we'll deploy our TODO app to our first "production" server in AWS meaning that you *will* need to [create an AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) to follow along.

{blurb, class:information}
AWS prices and offers will vary so this book can't provide any strong guarantees about what this would cost you.  However, at the time of this writing the examples in this chapter would fit well within the current AWS free tier, which is 750 hours of a `t3.micro` instance.

Even if there were no free tier, the cost of a `t3.micro` instance is currently ≈1¢ / hour or ≈ $10 / month if you never shut it off (and you can shut it off when you're not using it).  So at most this chapter should only cost you a few cents from start to finish.

Throughout this book I'll take care to minimize your expenditures by showing how you to develop and test locally as much as possible.
{/blurb}

In the spirit of Infrastructure as Code, we'll be using Terraform to declaratively provision AWS resources, but before doing so we need to generate AWS access keys for programmatic access.

## Configuring your access keys

To generate your access keys, follow the instructions in [Accessing AWS using AWS credentials](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html).

In particular, take care to **not** generate access keys for your account's root user.  Instead, use the Identity and Access Management (IAM) service to create a separate user with "Admin" privileges and generate access keys for that user.  The difference between a root user and an admin user is that an admin user's privileges can later be limited or revoked, but the root user's privileges can never be limited nor revoked.

{blurb, class:information}
The above AWS documentation also recommend generating temporary access credentials instead of long-term credentials.  However, setting this up properly and ergonomically requires setting up the IAM Identity Center which is only permitted for AWS accounts that have set up an AWS Organization.  That is way outside of the scope of this book so instead you should just generate long-term credentials for a non-root admin account.
{/blurb}

If you generated the access credential correctly you should have:

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
  Enter a value: us-east-1
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

public_dns = "ec2-…-2.compute.amazonaws.com"
```

The final output will include the URL for your server.  If you open that URL in your browser you will see the exact same TODO server as before, except now running on AWS instead of inside of a `qemu` virtual machine.  If this is your first time deploying something to AWS then congratulations!
