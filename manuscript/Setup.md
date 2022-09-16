# Setting up your development environment

I'd like you to be able to follow along with the examples in this book, so this chapter provides a quick setup guide to bootstrap from nothing to deploying a blank NixOS system using AWS EC2 that you can use for experimentation.  We're not going to speedrun the setup, though; instead I'll gently guide you through the setup process and the rationale behind each choice.

Some of these initial setup instructions are only appropriate for personal use.  For example, this chapter will use NixOps to provision our first NixOS system, even though I would not endorse NixOps for use in production.  As the book progresses I'll show you how to evolve this casual setup into a more professional setup, but it will take time to get there.

On the other hand, some of these initial setup instructions are "production-grade", so throughout this book I will highlight when I'm teaching you the most reliable way to do something, using an insert like this:

{icon: star}
{blurb}
If you see a star next to an insert, that means that I endorse the corresponding advice for professional use.
{/blurb}

## Install Nix

You've likely already installed Nix if you're reading this book, but I'll still cover how to do this because I have a few tips to share.

First off, I highly recommend installing Nix in multi-user mode if you have the option, even if nobody else is using your current machine.  In other words, multi-user mode is not just for production machines or shared infrastructure: even developers should install Nix in multi-user mode on their respective development machines.

You will save yourself headaches if you consistently enforce multi-user mode across the board because it will protect Nix builds from tampering with user-owned files and, vice versa, protect users from unintentionally tampering with the `/nix/store`.  Multi-user mode also enforces good security defaults, meaning that end users would have to acquire `root` privileges if they want to do potentially dangerous things.

The main reason to not install multi-user mode is if your system just plain does not support it.  For example, if you use a Linux distribution that does not support `systemd` then you would have to manually configure your init system to launch the Nix daemon.  If you're not sure if this is the case, you can still try to run the multi-user installation script anyway:

```bash
$ sh <(curl --location https://nixos.org/nix/install) --daemon
```

… since the installation script will stop and warn the end user if the system doesn't use `systemd`.

{blurb, class: information}
Throughout this book I'll use consistently long option names instead of short names (e.g. `--location` instead of `-L`), for two reasons:

- Long option names are more self-documenting

- Long option names are easier to remember

For example, `tar --extract --file` is clearer and a better mnemonic than `tar xf`.

You may freely use shorter option names if you prefer, though, but I still highly recommend using long option names at least for non-interactive scripts.
{/blurb}

Note the absence of star for the above command!  That's because  I can think of a few ways we can still improve upon the command.

First, you will also want to pin the version of Nix that you install if you're creating setup instructions for others to follow.  For example, this book will be based on Nix version 2.11.0, and you can pin the Nix version like this:

```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}") --daemon
```

… and you can find the full set of available releases by visiting the [release file server](https://releases.nixos.org/?prefix=nix/).

However, there are a few more options that the script accepts that we're going to make good use of, and we can list those options by supplying `--help` to the script:

```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}") --help
…

Nix Installer [--daemon|--no-daemon] [--daemon-user-count INT] [--no-channel-add] [--no-modify-profile] [--nix-extra-conf-file FILE]
Choose installation method.

 --daemon:    Installs and configures a background daemon that manages the store,
              providing multi-user support and better isolation for local builds.
              Both for security and reproducibility, this method is recommended if
              supported on your platform.
              See https://nixos.org/manual/nix/stable/installation/installing-binary.html#multi-user-installation

 --no-daemon: Simple, single-user installation that does not require root and is
              trivial to uninstall.
              (default)

 --no-channel-add:    Don't add any channels. nixpkgs-unstable is installed by default.

 --no-modify-profile: Don't modify the user profile to automatically load nix.

 --daemon-user-count: Number of build users to create. Defaults to 32.

 --nix-extra-conf-file: Path to nix.conf to prepend when installing /etc/nix/nix.conf

 --tarball-url-prefix URL: Base URL to download the Nix tarball from.
```

{blurb: warning}
You might wonder if you can use the `--tarball-url-prefix` option for distributing a custom build of Nix, but that's not what this option is for.  You can only use this option to download Nix from a different location, because the new download still has to match the same integrity check as the old download.

Don't worry, though; there still is a way to distribute a custom build of Nix, but we'll get to that further below.
{/blurb}

The extra options of interest to us are:

- `--nix-extra-conf-file`

  This provides a hook you can use to extend the `nix.conf` if you want to make sure that all users within you organization share the same settings.

- `--no-channel-add`

  You can (and should) enable this option within a professional organization to disable the preinstallation of any channels.

These two options are crucial because we are going to use them to disable the use of channels and replace them with the use of flakes.

{blurb: warning}
Channels are a trap and I treat them as a legacy Nix feature poorly suited for professional development, despite how ingrained they are in the Nix ecosystem.

The issue with channels is that they essentially introduce impurity into your builds by depending on the `NIX_PATH` and there aren't great solutions for enforcing that every Nix user or every machine within your organization has the exact same `NIX_PATH`.

Moreover, Nix now supports flakes, which you can think of as a more modern alternative to channels.  Familiarity with flakes is not a precondition to reading this book, though: I'll teach you what you need to know.
{/blurb}

So what we're going to do is:

- Disable channels by default

  Developers can still opt in to channels by installing them, but disabling channels by default will discourage people from contributing Nix code that depends on the `NIX_PATH`.

- Append the following setting to `nix.conf`

  ```bash
  experimental-features = nix-command flakes
  ```

  We'll use this setting throughout the rest of this book so that we can make use of Nix's newer support for flakes.

So the final installation script we'll end up with (complete with a star!) is:

{icon: star}
{blurb}
```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ CONFIGURATION='experimental-features = nix-command flakes'
$ sh <(curl --location "${URL}") \
    --daemon \
    --no-channel-add \
    --nix-extra-conf-file <(<<< "${CONFIGURATION}")
```
{/blurb}

{blurb, class:information}
The prior command only works if your shell is Bash and all shell commands throughout this book assume the use of Bash.

For example, the above command uses Bash's support for process substitution because otherwise we'd have to create a temporary file to store the `CONFIGURATION` and clean up the temporary file afterwards (which is tricky to do 100% reliably).  Process substitution is also more reliable than a temporary file because it happens entirely in memory and the intermediate result can't be accidentally deleted.

This may seem paranoid, but I've encountered stranger shell script failures than that, so I program very defensively.
{/blurb}
