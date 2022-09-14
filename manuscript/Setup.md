# Setting up your development environment

I'd like you to be able to follow along with the examples in this book, so this chapter provides a quick setup guide to bootstrap from nothing to deploying a blank NixOS system using AWS EC2 that you can use for experimentation.  We're not going to speedrun the setup, though; instead I'll gently guide you through the setup process and the rationale behind each choice.

Some of these initial setup instructions are only appropriate for personal use.  For example, this chapter will use NixOps to provision our first NixOS system, even though I would not endorse NixOps for use in production.  However, as the book progresses I'll show you how to evolve this casual setup into a more professional setup, but it will take time to get there.

On the other hand, some of these initial setup instructions are "production-grade", so throughout this book I will highlight when I'm teaching you the best way to do something, using an insert like this:

{icon: star}
{blurb}
If you see a star, that means that I endorse something for production use
{/blurb}

## Install Nix

You've likely already installed Nix if you're reading this book, but I'll still cover this because I still have a few tips to share.

First off, I highly recommend installing Nix in multi-user mode if you have the option, even if nobody else is using your current machine.  In other words, multi-user mode is not just for production machines or shared infrastructure: even developers should install Nix in multi-user mode on their development machine.

You will save yourself headaches if you consistently enforce multi-user mode across the board because it will protect Nix builds from tampering with user-owned files and, vice versa, protect users from unintentionally tampering with the `/nix/store`.  Multi-user mode also enforces good security defaults, meaning that end users would have to acquire `root` privileges if they want to do potentially insecure things.

The only good reason not to install multi-user mode is if your system just plain does not support it.  For example, if you use a Linux distribution that does not support `systemd` then you would have to manually configure your init system to launch the Nix daemon.  If you're not sure if this is the case, you can still run the multi-user installation script anyway:

```bash
$ sh <(curl --location https://nixos.org/nix/install) --daemon
```

{blurb, class: information}
Throughout this book I'll use consistently long option names instead of short names (e.g. `--location` instead of `-L`), for two reasons:

- Long option names are more self-documenting

- Long option names are easier to remember

For example, `tar --extract --file` is clearer and a better mnemonic than `tar xf`.

You may freely use shorter option names if you prefer, though, but I still highly recommend using long option names at least for non-interactive scripts.
{/blurb}

The script will stop and warn the end user if the system doesn't use `systemd`, in which case you can switch to the single-user script if you so desire.

Note the absence of star for the above command!  That's because we can still improve upon the command in a few ways.

First, you will also want to pin the version of Nix that you install if you're creating setup instructions for others to follow.  For example, this book will be based on Nix version 2.11.0, so we will want to use a different URL to pin the Nix version:

```bash
$ sh <(curl --location https://releases.nixos.org/nix/nix-2.11.0/install) --daemon
```

… and you can find the full set of available releases by visiting the [release file server](https://releases.nixos.org/?prefix=nix/)

However, there are a few more options that the script accepts that we're going to make good use of, and we can list those options by supplying `--help` to the script:

```bash
$ sh <(curl --location https://releases.nixos.org/nix/nix-2.11.0/install) --help
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
You might be interested in using the `--tarball-url-prefix` option for distributing a custom build of Nix, but that's not what this option is for.  This option only exists so that the end user can download Nix from a different location.  The new bundle still has to match an integrity check, so you can't use this to install a custom build.

Don't worry, though; there still is a way to ergonomically distribute a custom build of Nix, but we'll get to that further below.
{/blurb}

The extra options of interest to us are:

- `--nix-extra-conf-file`

  This provides a hook you can use to extend the `nix.conf` if you want to ensure uniform settings across all of your users.

- `--no-channel-add`

  You can (and should) enable this option within a professional organization to disable the preinstallation of any channels

These two options are crucial because we are going to use them to disable the use of channels and replace them with the use of flakes.

{blurb: warning}
Channels are a trap and I treat them as a legacy Nix feature completely unsuitable for professional Nix development, despite how ingrained they are in the Nix ecosystem.

The fundamental issue with channels is that they essentially introduce impurity into your development environments or deploys because there is no good way to ensure that every Nix user or every machine within your organization is using the exact same version of a given Nix channel.

Moreover, Nix now supports flakes, which you can think of as a more modern alternative to channels.  Familiarity with flakes is not a precondition to reading this book, though: I'll teach you what you need to know.
{/blurb}

So what we're going to do is:

- Disable channels by default

- Append the following setting to `nix.conf`

  ```bash
  experimental-features = nix-command flakes
  ```

  We'll use this setting throughout the rest of this book so that we can make use of Nix's newer support for flakes.

So the final installation script we'll end up with (complete with a star!) is:

{icon: star}
{blurb}
```bash
$ sh <(curl --location https://releases.nixos.org/nix/nix-2.11.0/install) --daemon --no-channel-add --nix-extra-conf-file <(<<< 'experimental-features = nix-command flakes')
```
{/blurb}

{blurb, class:information}
The prior command only works if your shell is Bash and all shell commands throughout assume the use of Bash.  This isn't due to some aesthetic preference of mine for Bash; rather, I'm relying on certain Bash features which are unavailable in a standard POSIX shell.

As an example, the above command uses process substitution so that we don't have to split the command into smaller commands like this:

```bash
$ EXTRA_CONFIG=$(mktemp)
$ echo 'experimental-features = nix-command flakes' > "${EXTRA_CONFIG}"
$ sh <(curl --location https://releases.nixos.org/nix/nix-2.11.0/install) --daemon --no-channel-add --nix-extra-conf-file "${EXTRA_CONFIG}"
```

This is not only longer, but less reliable, because the temporary file might be deleted in between creation and usage.  This might seem paranoid, but I've had to debug much weirder failure modes than that.
{/blurb}
