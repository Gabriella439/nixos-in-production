# Setting up your development environment

I'd like you to be able to follow along with the examples in this book, so this chapter provides a quick setup guide to bootstrap from nothing to deploying a blank NixOS system that you can use for experimentation.

## Installing Nix

In order to follow along with this book you will need the following requirements:

- Nix version 2.18.1 or newer

- Flake support enabled

  Specifically, you'll need to enable the following experimental features in your [Nix configuration file](https://nixos.org/manual/nix/stable/command-ref/conf-file.html):

  ```
  extra-experimental-features = nix-command flakes repl-flake
  ```

You've likely already installed Nix if you're reading this book, but I'll still cover how to do this because I have a few tips to share that can help you author a more reliable installation script for your colleagues.

Needless to say, if you or any of your colleagues are using NixOS as your development operating system then you don't need to install Nix and you can skip to the [Running a NixOS Virtual Machine](#running-a-nixos-virtual-machine) section below.

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

Depending on your platform the download instructions might also tell you to pass the `--daemon` or `--no-daemon` option to the installation script to specify a single-user or multi-user installation.  For simplicity, the instructions in this chapter will omit the `--daemon` / `--no-daemon` flag, but keep in mind the following platform-specific advice:

- *On macOS the installer defaults to a multi-user Nix installation*

  macOS doesn't even support a single-user Nix installation, so this is a good default.


- *On Windows the installer defaults to a single-user Nix installation*

  This default is also the recommended option.


- *On Linux the installer defaults to a single-user Nix installation*

  This is the one case where the default behavior is questionable.  Multi-user Nix installations are typically better if your Linux distribution supports `systemd`, so you should explicitly specify `--daemon` if you use `systemd`.

### Pinning the version

First, we will want to pin the version of Nix that you install if you're creating setup instructions for others to follow.  For example, this book will be based on Nix version 2.18.1, and you can pin the Nix version like this:

```bash
$ VERSION='2.18.1'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}")
```

… and you can find the full set of available releases by visiting the [release file server](https://releases.nixos.org/?prefix=nix/).

{blurb, class: information}
Feel free to use a Nix version newer than 2.18.1 if you want.  The above example installation script only pins the version 2.18.1 because that's what happened to be the latest stable version at the time of this writing.  That's also the Nix version that the examples from this book have been tested against.

The only really important thing is that everyone within your organization uses the same version of Nix, if you want to minimize your support burden.
{/blurb}

However, there are a few more options that the script accepts that we're going to make good use of, and we can list those options by supplying `--help` to the script:

```bash
$ VERSION='2.18.1'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}") --help
```

```
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
You might wonder if you can use the `--tarball-url-prefix` option for distributing a custom build of Nix, but that's not what this option is for.  You can only use this option to download Nix from a different location (e.g. an internal mirror), because the new download still has to match the same integrity check as the old download.

Don't worry, though; there still is a way to distribute a custom build of Nix, and we'll cover that in a later chapter.
{/blurb}

### Configuring the installation

The extra options of interest to us are:

- `--nix-extra-conf-file`

  This lets you extend the installed `nix.conf` if you want to make sure that all users within your organization share the same settings.


- `--no-channel-add`

  You can (and should) enable this option within a professional organization to disable the preinstallation of any channels.


These two options are crucial because we are going to use them to systematically replace Nix channels with flakes.

{blurb, class: warning}
Nix channels are a trap and I treat them as a legacy Nix feature poorly suited for professional development, despite how ingrained they are in the Nix ecosystem.

The issue with channels is that they essentially introduce impurity into your builds by depending on the `NIX_PATH` and there aren't great solutions for enforcing that every Nix user or every machine within your organization has the exact same `NIX_PATH`.

Moreover, Nix now supports flakes, which you can think of as a more modern alternative to channels.  Familiarity with flakes is not a precondition to reading this book, though: I'll teach you what you need to know.
{/blurb}

So what we're going to do is:

- *Disable channels by default*

  Developers can still opt in to channels by installing them, but disabling channels by default will discourage people from contributing Nix code that depends on the `NIX_PATH`.


- *Append the following setting to `nix.conf` to enable the use of flakes:*

  ```bash
  extra-experimental-features = nix-command flakes repl-flake
  ```


So the final installation script we'll end up with is:

```bash
$ VERSION='2.18.1'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ CONFIGURATION="
extra-experimental-features = nix-command flakes repl-flake
extra-trusted-users = ${USER}
"
$ sh <(curl --location "${URL}") \
    --no-channel-add \
    --nix-extra-conf-file <(<<< "${CONFIGURATION}")
```

{blurb, class: information}
The prior script only works if your shell is Bash or Zsh and all shell commands throughout this book assume the use of one of those two shells.

For example, the above command uses support for process substitution (which is not available in a POSIX shell environment) because otherwise we'd have to create a temporary file to store the `CONFIGURATION` and clean up the temporary file afterwards (which is tricky to do 100% reliably).  Process substitution is also more reliable than a temporary file because it happens entirely in memory and the intermediate result can't be accidentally deleted.
{/blurb}

{id: running-a-nixos-virtual-machine}
## Running a NixOS virtual machine

Now that you've installed Nix I'll show you how to launch a NixOS virtual machine (VM) so that you can easily test the examples throughout this book.

{id: darwin-builder}
### macOS-specific instructions

If you are using macOS, then follow the instructions in the [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/#sec-darwin-builder) to set up a local Linux builder.  We'll need this builder to create other NixOS machines, since they require Linux build products.

In particular, you will need to leave that builder running in the background while following the remaining examples in this chapter.  In other words, in one terminal window you will need to run:

```bash
$ nix run 'nixpkgs#darwin.linux-builder'
```

… and you will need that to be running whenever you need to build a NixOS system.  However, you can shut down the builder when you're not using it by giving the builder the `shutdown now` command.

{blurb, class:warning}
The `nix run nixpkgs#darwin.linux-builder` command is not enough to set up Linux builds on macOS.  Read and follow the full set of instructions from the Nixpkgs manual linked above.
{/blurb}

If you are using Linux (including NixOS or the Windows Subsystem for Linux) you can skip to the next step.

### Platform-independent instructions

Run the following command to generate your first project:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#setup'
```

… that will generate the following `flake.nix` file:

```nix
{ inputs = {
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";

    nixpkgs.url = "github:NixOS/nixpkgs/23.11";
  };

  outputs = { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

        base = { lib, modulesPath, ... }: {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          # https://github.com/utmapp/UTM/issues/2353
          networking.nameservers = lib.mkIf pkgs.stdenv.isDarwin [ "8.8.8.8" ];

          virtualisation = {
            graphics = false;

            host = { inherit pkgs; };
          };
        };

        machine = nixpkgs.lib.nixosSystem {
          system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;

          modules = [ base ./module.nix ];
        };

        program = pkgs.writeShellScript "run-vm.sh" ''
          export NIX_DISK_IMAGE=$(mktemp -u -t nixos.qcow2)

          trap "rm -f $NIX_DISK_IMAGE" EXIT

          ${machine.config.system.build.vm}/bin/run-nixos-vm
        '';

      in
        { packages = { inherit machine; };

          apps.default = {
            type = "app";

            program = "${program}";
          };
        }
    );
}
```

… and also the following `module.nix` file:

```nix
# module.nix

{ services.getty.autologinUser = "root";
}
```

Then run this command within the same directory to run our test virtual machine:

```
$ nix run
warning: creating lock file '…/flake.lock'
trace: warning: system.stateVersion is not set, defaulting to 23.11. …
…

Run 'nixos-help' for the NixOS manual.

nixos login: root (automatic login)


[root@nixos:~]# 
```

You can then shut down the virtual machine by entering `shutdown now`.

{blurb, class:information}
If you're unable to shut down the machine gracefully for any reason you can shut down the machine non-gracefully by typing `Ctrl`-`a` + `c` to open the `qemu` prompt and then entering `quit` to exit.

Also, don't worry about the `system.stateVersion` warning for now.  We'll fix that later.
{/blurb}

If you were able to successfully launch and shut down the virtual machine then you're ready to follow along with the remaining examples throughout this book.  If you see an example in this book that begins with this line:

```nix
# module.nix

…
```

… then that means that I want you to save that example code to the `module.nix` file and then restart the virtual machine by running `nix run`.

For example, let's test that right now; save the following file to `module.nix`:

```nix
# module.nix

{ services.getty.autologinUser = "root";

  services.postgresql.enable = true;
}
```

… then start the virtual machine and log into the machine.  As the `root` user, run:

```bash
[root@nixos:~]# sudo --user postgres psql
psql (14.5)
Type "help" for help.

postgres=#
```

… and now you should have command-line access to a `postgres` database.

The run script in the `flake.nix` file ensures that the virtual machine does not persist state in between runs so that you can safely experiment inside of the virtual machine without breaking upcoming examples.
