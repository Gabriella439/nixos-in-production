# Deploying to AWS using Terraform

Up until now we've been playing things safe and test-driving everything locally on our own machine.  We could even prolong this for quite as while because NixOS has advanced support for building and testing clusters of NixOS machines locally using virtual machines.  However, at some point we need to dive in and deploy a real server if we're going to use NixOS for real.

In this chapter we'll deploy our TODO app to our first "production" server in AWS meaning that you *will* need to [create an AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) to follow along.

{blurb, class:information}
AWS prices and offers will vary so this book can't provide any strong guarantees about what this would cost you.  However, at the time of this writing the examples in this chapter would fit well within the current AWS free tier, which is 750 hours of a `t3.micro` instance.

Even if there were no free tier, the cost of a `t3.micro` instance is currently ≈1¢ / hour or ≈ $10 / month if you never shut it off (and you can shut it off when you're not using it).  So at most this chapter should only cost you a few cents from start to finish.

Throughout this book I'll take care to minimize your expenditures by showing how you to develop and test locally as much as possible.
{/blurb}

## Configuring your access keys

For security reasons, you're going to want to follow the precautions noted for [Accessing AWS using AWS credentials](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html).  That means:

- You shouldn't generate access keys for your account root user
- You should be generating temporary access keys, not long-term access keys

In this section I'll assume that you have generated temporary access keys,
meaning that you have all three of:

- An access key ID (i.e. `AWS_ACCESS_KEY_ID`)
- A secret access key (i.e. `AWS_SECRET_ACCESS_KEY`)
- A session token (i.e. `AWS_SESSION_TOKEN`)

If you haven't already, configure your development environment to use these
tokens by running:

```bash
$ 
```
This section will assume that you have generated temporary access keys, meaning
that you have 

## Configuring AWS
