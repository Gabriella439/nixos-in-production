# Setting up your development environment

I'd like you to be able to follow along with the examples in this book, so this chapter provides a quick setup guide to bootstrap from nothing to deploying a blank NixOS system that you can use for experimentation.  We're not going to speedrun the setup, though; instead I'll gently guide you through the setup process and the rationale behind each choice.

## Installing Nix

You've likely already installed Nix if you're reading this book, but I'll still cover how to do this because I have a few tips to share that can help you author a more reliable installation script for your colleagues.

Needless to say, if you or any of your colleagues are using NixOS as your operating system then you don't need to install Nix and you can skip to the [Running a NixOS Virtual Machine](#running-a-nixos-virtual-machine) section below.

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

- On macOS the installer defaults to a multi-user Nix installation

  macOS doesn't even support a single-user Nix installation, so this is a good default.


- On Windows the installer defaults to a single-user Nix installation

  This default is also the recommended option.


- On Linux the installer defaults to a single-user Nix installation

  This is the one case where the default behavior is questionable.  Multi-user Nix installations are typically better if your Linux distribution supports `systemd`, so you should explicitly specify `--daemon` if you use `systemd`.

### Pinning the version

First, we will want to pin the version of Nix that you install if you're creating setup instructions for others to follow.  For example, this book will be based on Nix version 2.11.0, and you can pin the Nix version like this:

```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ sh <(curl --location "${URL}")
```

… and you can find the full set of available releases by visiting the [release file server](https://releases.nixos.org/?prefix=nix/).

{blurb, class: information}
Feel free to use a Nix version newer than 2.11.0 if you want.  The above example installation script only pins the version 2.11.0 because that's what happened to be the latest stable version at the time of this writing.  That's also the Nix version that the examples from this book have been tested against.

The only really important thing is that everyone within your organization uses the same version of Nix, if you want to minimize your support burden.
{/blurb}

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
You might wonder if you can use the `--tarball-url-prefix` option for distributing a custom build of Nix, but that's not what this option is for.  You can only use this option to download Nix from a different location (e.g. an internal mirror), because the new download still has to match the same integrity check as the old download.

Don't worry, though; there still is a way to distribute a custom build of Nix, and we'll cover that at the end of this chapter.
{/blurb}

### Configuring the installation

The extra options of interest to us are:

- `--nix-extra-conf-file`

  This lets you extend the installed `nix.conf` if you want to make sure that all users within your organization share the same settings.


- `--no-channel-add`

  You can (and should) enable this option within a professional organization to disable the preinstallation of any channels.


These two options are crucial because we are going to use them to systematically replace channels with flakes.

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
  extra-experimental-features = nix-command flakes repl-flake
  ```


So the final installation script we'll end up with is:

{icon: star}
{blurb}
```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ CONFIGURATION='extra-experimental-features = nix-command flakes repl-flake'
$ sh <(curl --location "${URL}") \
    --no-channel-add \
    --nix-extra-conf-file <(<<< "${CONFIGURATION}")
```

Note: if you see a star next to an insert like this one, that means that I won't suggest any further improvements to the instructions.  These starred inserts are the final "golden" instructions.
{/blurb}

{blurb, class: information}
The prior script only works if your shell is Bash or Zsh and all shell commands throughout this book assume the use of one of those two shells.

For example, the above command uses support for process substitution (which is not available in a POSIX shell environment) because otherwise we'd have to create a temporary file to store the `CONFIGURATION` and clean up the temporary file afterwards (which is tricky to do 100% reliably).  Process substitution is also more reliable than a temporary file because it happens entirely in memory and the intermediate result can't be accidentally deleted.
{/blurb}

{id: running-a-nixos-virtual-machine}
## Running a NixOS virtual machine

Now that you've installed Nix I'll show you how to launch a NixOS virtual machine (VM) so that you can easily test the examples throughout this book.

### macOS-specific instructions

If you are using macOS, then follow the instructions in the [`macos-builder`](https://github.com/Gabriella439/macos-builder) to set up a local Linux builder.  We'll need this builder to create other NixOS machines, since they require Linux build products.

If you are using Linux (including NixOS or the Windows Subsystem for Linux) you can skip to the next step.

### Platform-independent instructions

Save the following file to `flake.nix`:

```nix
{ inputs = {
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";

    nixpkgs.url = "github:NixOS/nixpkgs/f1a49e20e1b4a7eeb43d73d60bae5be84a1e7610";
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

        module = import ./module.nix;

        machine = nixpkgs.lib.nixosSystem {
          system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;

          modules = [ base module ];
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

… and also save the following file to `module.nix` within the same directory:

```nix
# module.nix

{ users.users.root.initialPassword = "";
}
```

{blurb, class: warning}
Obviously, the above NixOS configuration is not secure since it leaves the `root` account wide open.  We'll change this to something more secure later.
{/blurb}

Then run this command within the same directory to run our test virtual machine:

```
$ nix run
…

<<< Welcome to NixOS 22.11.20220918.f1a49e2 (aarch64) - ttyAMA0 >>>

Run 'nixos-help' for the NixOS manual.

nixos login: 
```

You can then log into the virtual machine as the `root` user and an empty password.  Once you successfully log in then shut down the virtual machine by typing `Ctrl`-`a` + `c` top open the `qemu` prompt and then type `quit` followed by `Enter` to exit.

If you successfully log into the virtual machine then you're ready to follow along with the remaining examples throughout this book.  If you see an example in this book that begins with this line:

```nix
# module.nix

…
```

… then that means that I want you to save that example code to the `module.nix` file and then restart the virtual machine by running `nix run`.

For example, let's test that right now; save the following file to `module.nix`:

```nix
# module.nix

{ users.users.root.initialPassword = "";

  services.postgresql.enable = true;
}
```

… then start the virtual machine and log into the machine.  As the `root` user,
run:

```bash
[root@nixos:~]# sudo --user postgres psql
psql (14.5)
Type "help" for help.

postgres=#
```

… and now you should have command-line access to a `postgres` database.

The run script in the `flake.nix` file ensures that the virtual machine does not persist state in between runs so that you can safely experiment inside of the virtual machine without breaking upcoming examples.

## Appendix: Installing a custom Nix build tool

Sometimes you need to patch the Nix build tool itself, perhaps because you need to incorporate a bug fix or a performance improvement.  There are essentially two ways that you can go about this:

- Install a stock Nix release and then use that to install a custom build of Nix

  This is simpler to build but this also entails more steps on behalf of the end user so there is more room for error.  However, you could automate those post-installation steps with a larger overarching install script.


- Install a custom build of Nix from the very beginning

  In other words, you can create an installation script just like the stock installer, except for your patched build of Nix.


I'll teach you how to do the latter because it's actually much easier than you might think!

### Patching Nix

No matter which installation method you choose you will need to create a `git` branch containing your desired changes to the Nix build tool.

If you don't already have a branch ready to go then you will need to hack on Nix by following the [development instructions from the Nix manual](https://nixos.org/manual/nix/stable/contributing/hacking.html).  However, if you already have a desired branch to install then you can skip that step.

You (the person creating the custom installer) will need to have Nix installed, but for this purpose a stock Nix installation will do just fine.  However, you will still need to follow the instructions from this chapter when installing Nix in order to enable the use of flakes.

You can now create a custom installation script from a branch of the Nix repository using the following command:

```bash
$ nix build "${BRANCH_REFERENCE}}#hydraJobs.installerScript"
```

… where in the common case `${BRANCH_REFERENCE}` will be one of the following:

- … an absolute or relative path to a checkout of your branch

  For example, if you `cd` into the local checkout of your repository you can specify `.` as the branch reference:

  ```bash
  $ nix build .#hydraJobs.installerScript
  ```


- A GitHub reference of the form: `github:${OWNER}/${REPOSITORY}/${BRANCH}`

  For example, if the Nix repository had an experimental branch named `experimental-branch` then you could create an installer for that branch like this:

  ```bash
  $ nix build github:NixOS/nix/fix_segmentation_fault
  ```

For some more examples of supported branch references, run `nix flake --help`.

{blurb, class: information}
You might wonder what's the point of supporting a GitHub reference if you could just do something like:

```bash
$ git clone "https://github.com/${OWNER}/${REPOSITORY}.git"
$ git checkout "${BRANCH}"
$ nix build .#hydraJobs.installerScript
```

The reason we prefer the GitHub reference goes back to the "master cue" from the "big picture" chapter:

> Every common build/test/deploy-related activity should be possible with at most one command using Nix's command line interface.

Here, we want to adhere to the master cue because doing so will allow us to exploit the Nix build tool's built-in support for caching `git` repositories.
{/blurb}

The result of the build is an installation script stored at `./result/install` that anybody behaves just like the stock installation script, except that all of the integrity checks now match your custom build of Nix:

```bash
$ tree ./result
./result
├── install
└── nix-support
    └── hydra-build-products
```

However, the default URL for the installation script needs 

If you were to host this installation script on a web server then users can install it using the same instructions as before:

```bash
$ VERSION='2.11.0'
$ URL="https://releases.nixos.org/nix/nix-${VERSION}/install"
$ CONFIGURATION='extra-experimental-features = nix-command flakes repl-flake'
$ sh <(curl --location "${URL}") \
    --no-channel-add \
    --nix-extra-conf-file <(<<< "${CONFIGURATION}")
```

