# Continuous Integration and Deployment

This chapter will cover how to use both continuous integration (a.k.a. "CI") and continuous deployment (a.k.a. "CD"), beginning with a brief explanation of what those terms mean.

Both continuous integration and continuous deployment emphasize *continuously* incorporating code changes into your product.  [*Continuous integration*](https://en.wikipedia.org/wiki/Continuous_integration) emphasizes continuously incorporating code changes into the trunk development branch of your version control repository whereas [*Continuous deployment*](https://en.wikipedia.org/wiki/Continuous_deployment) emphasizes continuously incorporating code changes into production.

## Continuous Integration

Colloquially developers often understand "continuous integration" to mean automatically testing pull requests before they are merged into version control.  However, continuous integration is about more than just automated tests and is really about ensuring that changes are regularly being integrated into the trunk development branch (and automated tests help with that).  For example, if you have long-lived development branches that's not really adhering to the spirit of continuous integration, even if you do put them through automated tests.

I'm mentioning this because this book will offer opinionated guidance that works better if you're not supporting long-lived development branches.  You can still modify this book's guidance to your tastes, but in my experience sticking to only one long-lived development branch (the trunk branch) will simplify your architecture, reduce communication overhead between developers, and improve your release frequency.  In fact, this specific flavor of continuous integration has a name: [trunk-based development](https://trunkbaseddevelopment.com/).

That said, this chapter will focus on how to set up automated tests since that's the part of continuous integration that's NixOS-specific.

The CI solution I endorse for most Nix/NixOS projects is [garnix](https://garnix.io/) because with garnix you don't have to manage secrets and you don't have to set up your own build servers or cache.  In other words, garnix is architecturally simple to install and manage.

However, garnix only works with GitHub (it's a [GitHub app](https://github.com/apps/garnix-ci)) so if you are using a different version control platform then you'll have to use a different CI solution.  The two major alternatives that people tend to use are:

- Hydra

  Like garnix, Hydra is a Nix-aware continuous integration service but unlike garnix, Hydra is self-hosted[^1].  Hydra's biggest strength is deep visibility into builds in progress and ease of scaling out build capacity but Hydra's biggest weakness is that it is high maintenance to support, and difficult to debug when things go wrong.


- A non-Nix-aware CI service that just runs `nix build`

  For example, you could have a GitHub action or Jenkins job that runs some `nix build` command on all pull requests.  The advantage of this approach is that it is very simple but the downside is that the efficiency is worse when you need to scale out your build capacity.

{blurb, class:information}
The reason why non-Nix-aware CI solutions tend to do worse at scale is because they typically have their own notion of available builders/agents/slots which does not map cleanly onto Nix's notion of available builders.  This means that you have to waste time tuning the two sets of builders to avoid wasting available build capacity and even after tuning you'll probably end up with wasted build capacity.

The reason Hydra doesn't have this problem is because Hydra uses Nix's native notion of build capacity ([remote builds](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html)) configured via the `nix.distributedBuilds` and `nix.buildMachines` NixOS options.  That means that you can easily scale out build capacity by adding more builders[^2].
{/blurb}

This chapter will focus on setting up garnix since it's dramatically simpler than the alternatives.

Also, we're going to try to minimize the amount of logic that needs to live outside of Nix.  For example:

- checks that you'd normally run in a non-Nix-aware job can be incorporated into a Nix build's check phase


- non-Nix-aware jobs that deploy ("push") a machine configuration can be replaced by machines periodically fetching and installing ("pulling") their configuration

  This is covered later in this chapter's [Continuous Deployment](#continuous-deployment) section.  For more discussion on the tradeoffs of "push" vs "pull" continuous deployment, see: [Push vs. Pull in GitOps: Is There Really a Difference?](https://thenewstack.io/push-vs-pull-in-gitops-is-there-really-a-difference/).

### garnix

garnix already has [official documentation](https://garnix.io/docs) for how to set it up, but I'll mention here the relevant bits for setting up CI for our own production deployment.  We're going to configure this CI to build and cache the machine that we deploy to production, which will also ensure that we don't merge any changes that break the build.

This exercise will build upon the same example as the [previous chapter on Terraform](#terraform), and you can reuse the example from that chapter or you can generate the example if you haven't already by running these commands:

```bash
$ mkdir todo-app
$ cd todo-app
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#terraform'
```

… or you can skip straight to the final result (minus the secrets file) by running:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#continuous-deployment'
```

garnix requires the use of Nix flakes in order to support [efficient evaluation caching](https://www.tweag.io/blog/2020-06-25-eval-cache/) and the good news is that we can already build our NixOS system without any changes to our flake, but it might not be obvious how at first glance.

If we wanted to build our system, we would run:

```bash
$ nix build '.#nixosConfigurations.default.config.system.build.toplevel'
```

{blurb, class:warning}
If your development system is Apple Silicon (i.e. `aarch64-darwin`) you will not yet be able to build that locally.  Even if you use the Linux builder from the [Setting up your development environment](#darwin-builder) chapter that won't work because the builder's architecture (`aarch64-linux`) won't match the architecture of the system we're deploying (`x86_64-linux`).

In the next chapter we'll cover how to set up an `x86_64-linux` remote builders that you can use for testing builds like these, but until then you will have to settle for just *evaluating* the system configuration instead of *building* it, like this:

```bash
$ nix eval '.#nixosConfigurations.default.config.system.build.toplevel'
```

This will catch errors at the level of Nix evaluation (e.g. Nix syntax errors or bad function calls) but this won't catch errors related to actually building the system.

In fact, if all you care about is evaluation, you can simplify that latter command even further by just running:

```bash
$ nix flake check
```

… which does exactly the same thing (among other things).  However, typically we want to build *and cache* our NixOS system, which is why we don't just run `nix flake check` in CI.
{/blurb}

### Attributes

Let's step through this attribute path:

```
nixosConfigurations.default.config.system.build.toplevel
```

… to see where each attribute comes from because that will come in handy if you choose to integrate Nix into a non-Nix-aware CI solution:

- `nixosConfigurations`

  This is one of the ["standard" output attributes](https://nixos.wiki/wiki/Flakes#Output_schema) for flakes where we store NixOS configurations that we want to build.  This attribute name is not just a convention; NixOS configurations stored under this attribute enjoy special support from Nix tools.  Specifically:

  - `nixos-rebuild` only supports systems underneath the `nixosConfigurations` output

     We use `nixos-rebuild` indirectly as part of our Terraform deployment because [the `terraform-nixos-ng` module uses `nixos-rebuild` under the hood](https://www.haskellforall.com/2023/01/terraform-nixos-ng-modern-terraform.html).  In our project's `main.tf` file the `module.nixos.flake` option is set to `.#default` which `nixos-rebuild` replaces with `.#nixosConfigurations.default`[^3].

  - `nix flake check` automatically checks the `nixosConfigurations` flake output

    … as noted in the previous aside.

  - [garnix's default configuration](https://garnix.io/docs/yaml_config) builds all of the `nixosConfigurations` flake outputs

    … so if we stick to using that output then we don't need to specify a non-default configuration.

- `default`

  We can store more than one NixOS system configuration underneath the `nixosConfigurations` output.  We can give each system any attribute name, but typically if you only have one system to build then the convention is to name that the `default` system.  The command-line tooling does not give this `default` attribute any special treatment, though.

- `config`

  The output of the `nixpkgs.lib.nixosSystem` system is similar in structure to a NixOS module, which means that it has attributes like `config` and `options`.  The `config` attribute lets you access the finalized values for all NixOS options.

- `system.build.toplevel`

  This is a NixOS option that stores the final derivation for building our NixOS system.  For more details, see the [NixOS option definitions](#nixos) chapter.

{blurb, class:information}
You can use `nix repl` to explore flake outputs by running:

```bash
$ nix repl .#
Welcome to Nix 2.18.1. Type :? for help.

Loading installable 'path:/Users/gabriella/proj/todo-app#'...
Added 1 variables.
nix-repl>
```

… and then you can use autocompletion within the REPL to see what's available.  For example:

```bash
nix-repl> nixosConfigurations.<TAB>
nix-repl> nixosConfigurations.default.<TAB>
nixosConfigurations.default._module        nixosConfigurations.default.extendModules  nixosConfigurations.default.options        nixosConfigurations.default.type
nixosConfigurations.default.config         nixosConfigurations.default.extraArgs      nixosConfigurations.default.pkgs
```
{/blurb}

### Enabling garnix CI

The only thing you'll need in order to enable garnix CI for your project is to:

- turn your local directory into a `git` repository

  ```bash
  $ git init
  $ git add --all
  $ git commit --message 'Initial commit'
  ```


- host your `git` repository on GitHub

  … by following [these instructions](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).

  Also, make this repository private, because later in this chapter we're going to practice fetching a NixOS configuration from a private repository.

- enable garnix on that repository

  … by visiting the [garnix GitHub app](https://github.com/apps/garnix-ci), installing it, and enabling it on your newly-created repository.


… and you're mostly done!  You won't see any activity, though, until you create your first pull request so you can verify that garnix is working by creating a pull request to make the following change to the `flake.nix` file:

```diff
--- a/flake.nix
+++ b/flake.nix
@@ -7,4 +7,12 @@
       modules = [ ./module.nix ];
     };
   };
+
+  nixConfig = {
+    extra-substituters = [ "https://cache.garnix.io" ];
+
+    extra-trusted-public-keys = [
+      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
+    ];
+  };
 }
```

Once you create that pull request, garnix will report two status checks on that pull request:

- "Evaluate flake.nix"

  This verifies that your `flake.nix` file is well-formed and also serves as a fallback status check you can use if your flake has no outputs (for whatever reason).

- "nixosConfig default"

  This status check verifies that our `nixosConfigurations.default` output builds correctly and caches it.

The next thing you need to do is to enable branch protection settings so that those new status checks gate merge into your `main` branch.  To do that, visit the
"Settings → Branches → Add branch protection rule" page of your repository (which you can also find at `https://github.com/${OWNER}/${REPOSITORY}/settings/branch_protection_rules/new` where `${OWNER}` is your username and `${REPOSITORY}` is the repository name you chose).  Then select the following options:

- Branch name pattern: `main`
- Require status checks to pass before merging
  - Status checks that are required:
    - "Evaluate flake.nix"
    - "nixosConfig default"

Since this is a tutorial project we won't enable any other branch protection settings, but for a real project you would probably want to enable some other settings (like requiring at least one approval from another contributor).

Once you've made those changes, merge the pull request you just created.  You've just set up automated tests for your repository!

### Using garnix's cache

One of the reasons I endorse garnix for most Nix/NixOS projects is that they also take care of hosting a cache on your behalf.  Anything built by your CI is made available from their cache.

The pull request you just merged configures your flake to automatically make use of garnix's cache.  If you were using an `x86_64-linux` machine, you could test this by running:

```bash
$ nix build .#nixosConfigurations.default.config.system.build.toplevel
```

{blurb, class:warning}
The above command does not work on other systems (e.g. `aarch64-darwin`), even though the complete build product is cached!  You would think that Nix would just download ("substitute") the complete build product even if there were a system mismatch, but this does not work because [Nix refuses to substitute certain derivations](https://github.com/NixOS/nix/issues/8677).  The above `nix build` command will only work if your local system is `x86_64-linux` or you have a remote builder configured to build `x86_64-linux` build products because Nix will insist on building some of the build products instead of substituting them.

It is possible to work around this by adding the following two `nix.conf` options (and restarting your Nix daemon):

```
extra-substituters = https://cache.garnix.io
extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=
```

… and then you can run:

```bash
$ FLAKE='.#nixosConfigurations.default.config.system.build.toplevel'
$ nix-store --realise "$(nix eval --raw "${FLAKE}.outPath")"
```

… but that's not as great of a user experience.
{/blurb}

{id: continuous-deployment}
## Continuous Deployment

We're going to be using "pull-based" continuous deployment to manage our server, meaning that our server will periodically fetch the desired NixOS configuration and install that configuration.

NixOS already has a set of [`system.autoUpgrade`](https://search.nixos.org/options?query=system.autoUpgrade) options for managing a server in this way.  What we want is to be able to set at least the following two NixOS options:

```nix
  system.autoUpgrade = {
    enable = true;

    flake = "github:${username}/${repository}#default";
  };
```

However, there's a catch: this means that our machine will need to be able to access our private `git` repository.  Normally the way you'd do this is to specify an access token in `nix.conf` like this:

```
access-tokens = github.com=${SECRET_ACCESS_TOKEN}
```

… but don't want to save this access token in version control in order to deploy our machine.

{blurb, class:information}
Another way we could fetch from a private git repository is to specify a flake like this:

```nix
    flake = "git+ssh://git@github.com/${username}/${repository}#default";
```

… which would allow us to access the private git repository using an SSH key pair instead of using a GitHub access token (assuming that we configure GitHub to grant that key pair access to the repository).  Either way, we'd need some sort of secret to be present on the machine in order to access the private repository.
{/blurb}

So we need some way to securely transmit or install secrets (such as personal access tokens) to our machine, but how do we bootstrap all of that?

For the examples in this book, we're going to reuse the SSH key pair generated for our Terraform deployment as a "primary key pair".  In other words, we're going to install the private key of our SSH key pair on the target machine and then use the corresponding public key (which we can freely share) to encrypt other secrets (which only our target machine can decrypt, using the private key).  In fact, our original Terraform template already does this:

```terraform
resource "aws_instance" "todo" {
  …

  # We will use this in a future chapter to bootstrap other secrets
  user_data = <<-EOF
    #!/bin/sh
    (umask 377; echo '${tls_private_key.nixos-in-production.private_key_openssh}' > /var/lib/id_ed25519)
    EOF
}
```

We are now living in the future and we're going to use the SSH private key mirrored to `/var/lib/id_ed25519` as the primary key that bootstraps all our other secrets.

This implies that our "admin" (the person deploying our machine using Terraform) will be able to transitively access all other secrets that the machine depends on because the admin has access to the same private key.  However, there's no real good way to prevent this sort of privilege escalation, because the admin has `root` access to the machine and good luck granting the machine access to a secret without granting the `root` user access to the same secret.[^4]

### `sops-nix`

We're going to use [`sops-nix`](https://github.com/Mic92/sops-nix) (a NixOS wrapper around [`sops`](https://github.com/getsops/sops)) to securely distribute all other secrets we need to our server.  The way that `sops-nix` works is:

- You generate an asymmetric key pair

  In other words, you generate a public key (used to encrypt secrets) and a matching private key (used to decrypt secrets encrypted by the public key).  This can be a [GPG](https://www.gnupg.org/gph/en/manual/c14.html), [SSH](https://man.openbsd.org/ssh-keygen), or [age](https://github.com/FiloSottile/age#readme) key pair.

  This is our "primary key pair".


- You install the private key on the target machine without using `sops`

  There is no free lunch here.  You can't bootstrap secrets on the target machine out of thin air.  The private key of our primary key pair needs to already be present on the machine so that the machine can decrypt secrets encrypted by the public key.


- You use `sops` to add new encrypted secrets

  `sops` is a command-line tool that makes it easy to securely edit a secrets file.  You can create a new secrets file using just the public key, but if you want to edit an existing secrets file (e.g. to add or remove secrets) you will require both the public key and private key.  In practice this means that only an admin can add new secrets.


- You use `sops-nix` decrypt those secrets

  `sops-nix` is a NixOS module that uses the private key (which we installed out-of-band) to decrypt the secrets file and make those secrets available as plain text files on the machine.  By default, those text files are only readable by the `root` user but you can customize the file ownership and permissions to your liking.

{blurb, class:information}
You might wonder what is the point of using `sops` to distribute secrets to the machine if it requires already having a secret present on the machine (the primary key).

The purpose of `sops` is to provide a uniform interface for adding, versioning, and installing all other secrets.  Otherwise, you'd have to roll your own system for doing this once you realize that it's kind of a pain to implement a secret distribution mechanism for each new secret you need.

So `sops` doesn't completely solve the problem of secrets management (you still have to figure out how to install the primary key), but it does make it easier to manage all the other secrets.
{/blurb}

### age keys

To use the `sops` command-line tool we'll need to convert our SSH primary key pair into an age key pair.  This step is performed by the admin who has access to both the SSH public key and the SSH private key and requires the `ssh-to-age` command-line tool, which you can obtain like this:

```bash
$ nix shell 'github:NixOS/nixpkgs/23.11#ssh-to-age'
```

The public key of our age key pair will be stored in a `.sops.yaml` configuration file which lives in version control.  To create the age public key, run:

```bash
$ cat > .sops.yaml <<EOF
creation_rules:
- age: '$(ssh-to-age -i id_ed25519.pub)'
EOF
```

The private key of our age key pair is stored locally by the admin so that they can edit secrets.  To store the age private key, run:

```bash
$ # On Linux
$ KEY_FILE=~/.config/sops/age/keys.txt

$ # On MacOS
$ KEY_FILE=~/Library/'Application Support'/sops/age/keys.txt

$ mkdir -p "$(dirname "$KEY_FILE")"
$ (umask 077; ssh-to-age -private-key -i id_ed25519 -o "$KEY_FILE")
```

Now you're ready to start reading and writing secrets!

### Creating the secret

Create a [fine-grained personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) by visiting the [New fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) page and entering the following settings:

- **Token name:** "todo app - continuous deployment"
- **Expiration:** 30 days
- **Description:** leave empty
- **Resource owner:** your personal GitHub account
- **Repository access:** choose "Only select repositories" and select your `todo-app` repository
- **Repository permissions:** set the "Contents" permission to "Read-only"
- **Account permissions:** do not enable any account permissions

… and then click the "Generate token" button.  Keep this page with the generated token open for just a second.

Fetch the `sops` command-line tool by running:

```bash
$ nix shell 'github:NixOS/nixpkgs/23.11#sops'
```

… and then create a new secrets file by running:

```bash
$ sops secrets.yaml
```

That will open a new file in your editor with the following contents:

```yaml
hello: Welcome to SOPS! Edit this file as you please!
example_key: example_value
# Example comment
example_array:
    - example_value1
    - example_value2
example_number: 1234.56789
example_booleans:
    - true
    - false
```

We're going to do what file says and edit the file how we please.  Delete the entire file and replace it with:

```yaml
github-access-token: 'extra-access-tokens = github.com=github_pat_…'
```

… replacing `github_pat_…` with the personal access token you just generated.

Now if you save, exit, and view the file (without `sops`) you will see something like this:

```yaml
github-access-token: …
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
        - recipient: …
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            …
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "…"
    mac: ENC[AES256_GCM,data:…,iv:…,tag:…,type:str]
    pgp: []
    unencrypted_suffix: _unencrypted
    version: 3.7.3
```

… and since you're the admin you can still decrypt the file using `sops` to view the secret:

```bash
$ sops secrets.yaml
```

Anyone who doesn't have access to the private key would instead get an error message like this:

```
Failed to get the data key required to decrypt the SOPS file.

Group 0: FAILED
  …: FAILED
    - | failed to open file: open
      | …/sops/age/keys.txt: no such file or directory

Recovery failed because no master key was able to decrypt the file. In
order for SOPS to recover the file, at least one key has to be successful,
but none were.
```

### Installing the secret

Now we can distribute the GitHub personal access token stored inside of `secrets.yaml`.  First we'll need to import the `sops-nix` NixOS module by modifying our `flake.nix` file like this:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    sops-nix.url = "github:Mic92/sops-nix/bd695cc4d0a5e1bead703cc1bec5fa3094820a81";
  };

  outputs = { nixpkgs, sops-nix, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [ ./module.nix sops-nix.nixosModules.sops ];
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
}
```

Then we'll enable continuous deployment by adding the following lines to `module.nix`:

```nix
{ modulesPath, ... }:

{ …

  sops = {
    defaultSopsFile = ./secrets.yaml;

    age.sshKeyPaths = [ "/var/lib/id_ed25519" ];

    secrets.github-access-token = { };
  };

  nix.extraOptions = "!include /run/secrets/github-access-token";
}
```

That will:

- Install the secret on our server

  That uses the `/var/lib/id_ed25519` private key that Terraform installed to decrypt the `secrets.yaml` file.


- Incorporate the secret into the Nix configuration

  This grants our Nix daemon access to our private `git` repository containing our NixOS configuration.


### The `autoUpgrade` service

Finally, to enable continuous deployment, we will enable `system.autoUpgrade`:

```nix
{ modulesPath, ... }:

{ …

  system.autoUpgrade = {
    enable = true;

    # Replace ${username}/${repository} with your repository's address
    flake = "github:${username}/${repository}#default";

    # Poll the `main` branch for changes once a minute
    dates = "minutely";

    # You need this if you poll more than once an hour
    flags = [ "--option" "tarball-ttl" "0" ];
  };
```

but don't deploy this configuration just yet!  First, add all the changes we've made so far to version control:

```bash
$ nix flake update
$ git fetch origin main
$ git checkout -b continuous-deployment FETCH_HEAD
$ git add .sops.yaml secrets.yaml flake.nix flake.lock module.nix
$ git commit --message 'Enable continuous deployment'
$ git push --set-upstream origin continuous-deployment
```

Then create a pull request from those changes and merge the pull request once it passes CI.

Once you've merged your changes, checkout the `main` branch of your repository:

```bash
$ git checkout main
$ git pull --ff-only
```

… and deploy those changes using `terraform`, the same way we did in the previous chapter:

```bash
$ terraform apply
```

Once you've applied those changes your machine will begin automatically pulling its configuration from the `main` branch of your repository.

### Testing continuous deployment

There are some diagnostic checks you can do to verify that everything is working correctly, but first you need to log into the machine using:

```bash
$ ssh -i id_ed25519 "root@${ADDRESS}"
```

… replacing `${ADDRESS}` with the `public_dns` output of the Terraform deployment.

Then you can check that the secret was correctly picked up by the Nix daemon by running:

```bash
[root@…:~]# nix --extra-experimental-features 'nix-command flakes' show-config | grep access-tokens
access-tokens = github.com=github_pat_…
```

… and you can also monitor the upgrade service by running:

```bash
[root@…:~]# journalctl --output cat --unit nixos-upgrade --follow
```

… and if things are working then every minute you should see the service output something like this:

```bash
Starting NixOS Upgrade...
warning: ignoring untrusted flake configuration setting 'extra-substituters'
warning: ignoring untrusted flake configuration setting 'extra-trusted-public-keys'
building the system configuration...
warning: ignoring untrusted flake configuration setting 'extra-substituters'
warning: ignoring untrusted flake configuration setting 'extra-trusted-public-keys'
updating GRUB 2 menu...
switching to system configuration /nix/store/…-nixos-system-unnamed-…
activating the configuration...
setting up /etc...
sops-install-secrets: Imported /etc/ssh/ssh_host_rsa_key as GPG key with fingerprint …
sops-install-secrets: Imported /var/lib/id_ed25519 as age key with fingerprint …
reloading user units for root...
Successful su for root by root
pam_unix(su:session): session opened for user root(uid=0) by (uid=0)
pam_unix(su:session): session closed for user root
setting up tmpfiles
finished switching to system configuration /nix/store/…-nixos-system-unnamed-…
nixos-upgrade.service: Deactivated successfully.
Finished NixOS Upgrade.
nixos-upgrade.service: Consumed … CPU time, no IP traffic.
```

Now let's test that our continuous deployment is working by making a small change so that we don't need to add the `--extra-experimental-features` option to every `nix` command.

Add the following option to `module.nix`:

```nix
  nix.settings.extra-experimental-features = [ "nix-command" "flakes" ];        
```

… and create and merge a pull request for that change.  Once your change is merged the machine will automatically pick up the change on the next minute boundary and you can verify the change worked by running:

```
[root@…:~]# nix show-config
```

… which will now work without the `--extra-experimental-features` option.

Congratulations!  You've now set up a continuous deployment system!

[^1]: At the time of this writing there is work in progress on a hosted Hydra solution called [Cloudscale Hydra](https://cloudscalehydra.com/), but that is not currently available.
[^2]: Okay, there is actually a limit to how much you can scale out build capacity.  After a certain point you will begin to hit bottlenecks in instantiating derivations at scale, but even in this scenario Hydra still has a higher performance ceiling than the the non-Nix-aware alternatives.
[^3]: I have no idea why `nixos-rebuild` works this way and doesn't accept the full attribute path including the `nixosConfigurations` attribute.
[^4]: There are some ways you can still prevent privilege escalation by the `root` user, like multi-factor authentication, but do you really want some other person to have to multi-factor authenticate every time one of your machines polls GitHub for the latest configuration?  It's much simpler to just trust your admin.
