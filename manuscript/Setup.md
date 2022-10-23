# Setting up your development environment

I'd like you to be able to follow along with the examples in this book, so this chapter provides a quick setup guide to bootstrap from nothing to deploying a blank NixOS system using AWS EC2 that you can use for experimentation.  We're not going to speedrun the setup, though; instead I'll gently guide you through the setup process and the rationale behind each choice.

## Install Nix

You've likely already installed Nix if you're reading this book, but I'll still cover how to do this because I have a few tips to share that can help you author a more reliable installation script for your colleagues.

Needless to say, if you or any of your colleagues are using NixOS as your operating system then you don't need to install Nix and you can skip to the [Blank NixOS Virtual Machine](#blank-nixos-virtual-machine) section below.

### Default installation

If you go to the [download page for Nix](https://nixos.org/download.html) it will tell you to run something similar to this:

```bash
$ sh <(curl --location https://nixos.org/nix/install)
```

{blurb, class: information}
Throughout this book I'll use consistently long option names instead of short names (e.g. `--location` instead of `-L`), for two reasons:

- Long option names are more self-documenting

- Long option names are easier to remember

For example, `tar --extract --file` is clearer and a better mnemonic than `tar xf`.

You may freely use shorter option names if you prefer, though, but I still highly recommend using long option names at least for non-interactive scripts.
{/blurb}

Depending on your platform the download instructions might also tell you to pass the `--daemon` or `--no-daemon` option to the installation script to specify a single-user or multi-user installation.  For simplicity, the instructions in this chapter will omit the `--daemon` / `--no-daemon` flag since the default behavior on each platform is okay at the time of this writing:

* On macOS the installer defaults to a multi-user Nix installation

  macOS doesn't even support a single-user Nix installation, so this is a good default.

* On Windows the installer defaults to a single-user Nix installation

  This default is also the recommended option.

* On Linux the installer defaults to a single-user Nix installation

  This is one case where the default is questionable.  Multi-user Nix installations are typically better if your Linux distribution supports `systemd`, but it's not the end of the world if you do a single-user Nix installation.

### Pinning the version

First, we will want to pin the version of Nix that you install if you're creating setup instructions for others to follow.  For example, this book will be based on Nix version 2.11.0, and you can pin the Nix version like this:

```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}")
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

{blurb, class: warning}
You might wonder if you can use the `--tarball-url-prefix` option for distributing a custom build of Nix, but that's not what this option is for.  You can only use this option to download Nix from a different location, because the new download still has to match the same integrity check as the old download.

Don't worry, though; there still is a way to distribute a custom build of Nix, and we'll cover that further below.
{/blurb}

### Configuring the installation

The extra options of interest to us are:

- `--nix-extra-conf-file`

  This provides a hook you can use to extend the `nix.conf` if you want to make sure that all users within you organization share the same settings.

- `--no-channel-add`

  You can (and should) enable this option within a professional organization to disable the preinstallation of any channels.

These two options are crucial because we are going to use them to disable the use of channels and replace them with the use of flakes.

{blurb, class: warning}
Channels are a trap and I treat them as a legacy Nix feature poorly suited for professional development, despite how ingrained they are in the Nix ecosystem.

The issue with channels is that they essentially introduce impurity into your builds by depending on the `NIX_PATH` and there aren't great solutions for enforcing that every Nix user or every machine within your organization has the exact same `NIX_PATH`.

Moreover, Nix now supports flakes, which you can think of as a more modern alternative to channels.  Familiarity with flakes is not a precondition to reading this book, though: I'll teach you what you need to know.
{/blurb}

So what we're going to do is:

- Disable channels by default

  Developers can still opt in to channels by installing them, but disabling channels by default will discourage people from contributing Nix code that depends on the `NIX_PATH`.

- Append the following setting to `nix.conf` to enable the use of flakes:

  ```bash
  experimental-features = nix-command flakes repl-flake
  ```

So the final installation script we'll end up with is:

{icon: star}
{blurb}
```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ CONFIGURATION='experimental-features = nix-command flakes repl-flake'
$ sh <(curl --location "${URL}") \
    --no-channel-add \
    --nix-extra-conf-file <(<<< "${CONFIGURATION}")
```

Note: if you see a star next to an insert like this one, that means that I won't suggest any further improvements to the instructions.
{/blurb}

{blurb, class:information}
The prior command only works if your shell is Bash or Zsh and all shell commands throughout this book assume the use of one of those two shells.

For example, the above command uses support for process substitution (which is not available in POSIX shell) because otherwise we'd have to create a temporary file to store the `CONFIGURATION` and clean up the temporary file afterwards (which is tricky to do 100% reliably).  Process substitution is also more reliable than a temporary file because it happens entirely in memory and the intermediate result can't be accidentally deleted.

This may seem paranoid, but I've encountered stranger shell script failures than that, so I program very defensively.
{/blurb}

{blurb, class:information}
Feel free to use a Nix version newer than 2.11.0 if you want.  The above example installation script only pins the version 2.11.0 because that's what happened to be the latest stable version at the time of this writing.  That's also the Nix version that the examples from this book have been tested against.

The only really important thing is that everyone within your organization uses the same version of Nix.
{/blurb}
