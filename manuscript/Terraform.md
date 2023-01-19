# Deploying to AWS using Terraform

Up until now we've been playing things safe and test-driving everything locally on our own machine.  We could even prolong this for quite as while because NixOS has advanced support for building and testing clusters of NixOS machines locally using virtual machines.  However, at some point we need to dive in and deploy a real server if we're going to use NixOS for real.

In this chapter we'll deploy our TODO app to our first "production" server in AWS meaning that you *will* need to [create an AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) to follow along.

{blurb, class:information}
AWS prices and offers will vary so this book can't provide any strong guarantees about what this would cost you.  However, at the time of this writing the examples in this chapter would fit well within the current AWS free tier, which is 750 hours of a `t3.micro` instance.

Even if there were no free tier, the cost of a `t3.micro` instance is currently ≈1¢ / hour or ≈ $10 / month if you never shut it off (and you can shut it off when you're not using it).  So at most this chapter should only cost you a few cents from start to finish.

Throughout this book I'll take care to minimize your expenditures by showing how you to develop and test locally as much as possible.
{/blurb}

In the spirit of Infrastructure as Code, we'll be using `terraform` to declaratively provision AWS resources, but before doing so we need to generate AWS access keys for programmatic access.

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
$ nix run github:NixOS/nixpkgs/22.11#awscli configure
AWS Access Key ID [None]: …
AWS Secret Access Key [None]: …
Default region name [None]: …
Default output format [None]: 
```

If you're not sure what region to use, pick the one closest to you based on
the list of [AWS service endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html).
