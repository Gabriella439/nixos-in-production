# Flakes

This book has leaned pretty heavily on Nix's support for "flakes", but I've glossed over the details of how flakes work despite how much we've already been using them.  In this chapter I'll give a more patient breakdown of flakes.

Most of what this chapter will cover is information that you can already find from other resources, like the [NixOS Wiki page on Flakes](https://nixos.wiki/wiki/Flakes#Flake_schema) or by running `nix help flake`.  However, I'll still try to explain flakes in my own words.

## Motivation

You can think of flakes as a package manager for Nix.  In other words, if we use Nix to build and distribute packages written in other programming languages (e.g.  Go, Haskell, Python), then flakes are how we "build" and distribute Nix packages.

Here are some example Nix packages that are distributed as flakes:

- `nixpkgs`

  This is the most widely used Nix package of all.  Nixpkgs is a giant `git` repository [hosted on GitHub](https://github.com/NixOS/nixpkgs) containing the vast majority of software packaged for Nix.  Nixpkgs also includes several important helper functions that you'll need for building even the simplest of packages, so you pretty much can't get anything done in Nix without using Nixpkgs to some degree.


- `flake-utils`

  This is a Nix package containing useful utilities for creating flakes and is itself distributed as a flake.


- `sops-nix`

  This is a flake we just used in the previous chapter to securely distribute secrets.

All three of the above packages provide reusable Nix code that we might want to incorporate into downstream Nix projects.  Flakes provide a way for us to depend on and integrate Nix packages like these into our own projects.

## Flakes, step-by-step

We can build a better intuition for how flakes work by starting from the simplest possible flake you can write:

```nix
# ./flake.nix

{ outputs = { nixpkgs, ... }: {
    # Replace *BOTH* occurrences of `x86_64-linux` with your machine's system
    #
    # You can query your current system by running:
    #
    # $ nix eval --impure --expr 'builtins.currentSystem'
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

You can then build and run that flake with this command:

```bash
$ nix run
Hello, world!
```

### Flake references

We could have also run the above command as:

```bash
$ nix run .
```

… or like this:

```bash
$ nix run '.#default'
```

… or in this fully qualified form:

```bash
$ # Replace x86_64-linux with your machine's system
$ nix run '.#packages.x86_64-linux.default'
```

In the above command `.#packages.x86_64-linux.default` uniquely identifies a "flake reference" and an attribute path, which are separated by a `#` character:

- The first half (the flake reference) specifies where a flake is located

  In the above example the flake reference is "`.`" (a shorthand for our current directory).

- The second half (the attribute path) specifies which output attribute to use

  In the above example, it is `packages.x86_64-linux.default` and `nix run` uses that output attribute path to select which executable to run.

Usually we don't want to write out something long like `.#packages.x86_64-linux.default` when we use flakes, so flake-enabled Nix commands provide a few convenient shorthands that we can use to shorten the command.

First off, many Nix commands will automatically expand part of the flake attribute path on your behalf.  For example, if you run:

```bash
$ nix run '.#default'
```

… then `nix run` will attempt to expand `.#default` to a fully qualified attribute path of `.#apps."${system}".default` and if the flake does not have that output attribute path then `nix run` will fall back to a fully qualified attribute path of `.#packages."${system}".default`.

Different Nix commands will expand the attribute path differently.  For example:

- `nix build` and `nix eval` expand `foo` to `packages."${system}".foo`

- `nix run` expands `foo` to `apps."${system}".foo`

  … and falls back to `packages."${system}".foo` if that's missing

- `nix develop` expands `foo` to `devShells."${system}".foo`

  … and falls back to `packages."${system}".foo` if that's missing

- `nixos-rebuild`'s `--flake` option expands `foo` to `nixosConfigurations.foo`

- `nix repl` will not expand attribute paths at all

In each case the `"${system}"` in the expanded attribute path corresponds to your current system, which you can query using this command:

```bash
$ nix eval --impure --expr 'builtins.currentSystem'
```

You can even omit the attribute path, in which case it will default to an attribute path of `default`.  For example, if you run:

```bash
$ nix run .
```

… then `nix run` will expand `.` to `.#default` (which will in turn expand to `.#packages.${system}.default` for our flake).

Furthermore, you can omit the flake reference, which will default to `.`, so if you run:

```bash
$ nix run
```

… then that expands to a flake reference of `.` (which will then continue to expand according to the above rules).

### Flake URIs

So far these examples have only used a flake reference of `.` (the current directory), but in this book we'll be using several types of flake references, including:

- paths

  These can be relative paths (like `.` or `./utils` or `../bar`), home-anchored paths (like `~/workspace`), or absolute paths (like `/etc/nixos`).  In all three cases the path must be a directory containing a `flake.nix` file.


- GitHub URIs

  These take the form `github:${OWNER}/${REPOSITORY}` or `github:${OWNER}/${REPOSITORY}/${REFERENCE}` (where `${REFERENCE}` can be a branch, tag, or revision).  Nix will take care of cloning the repository for you in a cached and temporary directory and (by default) look for a `flake.nix` file within the root directory of the repository.


- indirect URIs

  An indirect URI is one that refers to an entry in Nix's "flake registry".  If you run `nix registry list` you'll see a list of all your currently configured indirect URIs.

### Flake inputs

Normally the way flakes work is that you specify both inputs and outputs, like this:

```nix
{ inputs = {
    foo.url = "${FLAKE_REFERENCE}";
    bar.url = "${FLAKE_REFERENCE}";
  };

  outputs = { self, foo, bar }: {
    baz = …;
    qux = …;
  };
}
```

In the above example, `foo` and `bar` would be the flake inputs while `baz` and `qux` would be the flake outputs.  In other words, the sub-attributes nested underneath the `inputs` attribute are the flake inputs and the attributes generated by the `outputs` function are the flake outputs.

Notice how the `outputs` function takes input arguments which share the same name as the flake inputs because the flakes machinery resolves each input and then passes each resolved input as a function argument of the same name to the `outputs` function.

To illustrate this, if you were to build the `baz` output of the above flake using:

```bash
$ nix build .#baz
```

… then that would sort of be like building this Nix pseudocode:

```nix
let
  flake = import ./flake.nix;

  foo = resolveFlakeURI flake.inputs.foo;

  bar = resolveFlakeURI flake.inputs.baz;

  self = flake.outputs { inherit self foo bar; };

in
  self.baz
```

… where `resolveFlakeURI` would be sort of like a function from an input's flake reference to the Nix code packaged by that flake reference.

{blurb, class:information}
If you're curious how flake inputs and outputs are actually resolved, it's actually implemented as a function in Nix, which you can find [here in the `NixOS/nix` repository](https://github.com/NixOS/nix/blob/2.18.1/src/libexpr/flake/call-flake.nix).
{/blurb}

However, if you were paying close attention you might have noticed that our original example flake does not have any `input`s:

```nix
{ outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

… and the `outputs` function references a `nixpkgs` input which we never specified.  The reason this works is because flakes automatically convert missing inputs to "indirect" URIs that are resolved using Nix's flake registry.  In other words, it's as if we had written:

```nix
{ inputs = {
    nixpkgs.url = "nixpkgs";  # Example of an indirect flake reference
  };

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

An indirect flake reference is resolved by doing a lookup in the flake registry, which you can query yourself like this:

```bash
$ nix registry list | grep nixpkgs
global flake:nixpkgs github:NixOS/nixpkgs/nixpkgs-unstable
```

… so we could have also written:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

… which would have produced the same result: both flake references will attempt to fetch the `nixpkgs-unstable` branch of the `nixpkgs` repository to resolve the `nixpkgs` flake input.

{blurb, class:information}
Throughout the rest of this chapter (and book) I'm going to try to make flake references as pure as possible, meaning:

- no indirect flake references

  In other words, instead of `nixpkgs` I'll use something like `github:NixOS/nixpkgs/23.11`.


- all GitHub flake references will include a tag

  In other words, I won't use a flake reference like `github:NixOS/nixpkgs`.

Neither of these precautions are strictly necessary when using flakes because flakes lock their dependencies using a `flake.lock` file which you can (and should) store in version control.  However, it's still a good idea to take these precautions anyway even if you include the `flake.lock` file alongside your `flake.nix` file.  The more reproducible your flake references, the better you document how to regenerate or update your lock file.
{/blurb}

Suppose we were to use our own local `git` checkout of `nixpkgs` instead of a remote `nixpkgs` branch: we'd have to change the `nixpkgs` input to our flake to reference the path to our local repository (since paths are valid flake references), like this:

```nix
{ inputs = {
    nixpkgs.url = ~/repository/nixpkgs;
  };

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

… and then we also need to build the flake using the `--impure` flag:

```bash
$ nix build --impure
```

Without the flag we'd get this error message:

```
error: the path '~/repository/nixpkgs' can not be resolved in pure mode
```

{blurb, class:information}
Notice that we're using flake references in two separate ways:

- on the command line

  e.g. `nix build "${FLAKE_REFERENCE}"`

- when specifying flake inputs

  e.g. `inputs.foo.url = "${FLAKE_REFERENCE}";`

However, they differ in two important ways:

- command line flake references never require the `--impure` flag

  In other words, `nix build ~/proj/nixpkgs#foo` is fine, but if you specify `~/proj/nixpkgs` as a flake input then you have to add the `--impure` flag on the command line.


- flake inputs can be specified as attribute sets instead of strings

To elaborate on the latter point, instead of specifying a `nixpkgs` input  like this:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  …
}
```

We could instead specify the same input like this:

```nix
{ inputs = {
    type = "github";

    owner = "NixOS";

    repo = "nixpkgs";
  };

  …
}
```

Throughout this book I'll consistently use the non-structured (string) representation for flake references to keep things simple.
{/blurb}

### Flake outputs

We haven't yet covered what we actually *get* when we resolve a flake input.  For example, what Nix expression does a flake reference like `github:NixOS/nixpkgs/23.11` resolve to?

The answer is that a flake reference will resolve to the output attributes of the corresponding flake.  For a flake like `github:NixOS/nixpkgs/23.11` that means that Nix will:

- clone [the `nixpkgs` repository](https://github.com/NixOS/nixpkgs)

- check out [the `23.11` tag](https://github.com/NixOS/nixpkgs/tree/23.11) of that repository

- look for [a `flake.nix`](https://github.com/NixOS/nixpkgs/blob/23.11/flake.nix) file in the top-level directory of that repository

- resolve inputs for that flake

  For this particular flake, there are no inputs to resolve.

- look for [an `outputs` attribute](https://github.com/NixOS/nixpkgs/blob/23.11/flake.nix#L6), which will be a function

- computed the fixed-point of that function

- return that fixed-point as the result

  In this case the result would be an [attribute set](https://github.com/NixOS/nixpkgs/blob/23.11/flake.nix#L16-L74) containing five attributes: `lib`, `checks`, `htmlDocs`, `legacyPackages`, and `nixosModules`.

In other words, it would behave like this (non-flake-enabled) Nix code:

```nix
# nixpkgs.nix

let
  pkgs = import <nixpkgs> { };

  nixpkgs = pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "23.11";
    hash = "sha256-btHN1czJ6rzteeCuE/PNrdssqYD2nIA4w48miQAFloM=";
  };

  flake = import "${nixpkgs}/flake.nix";

  self = flake.outputs { inherit self; };

in
  self
```

… except that with flakes we wouldn't have to figure out what hash to use since that would be transparently managed for us by the flake machinery.

If you were to load the above file into the REPL:

```bash
$ nix repl --file nixpkgs.nix
```

… you would get the exact same result as if you had loaded the equivalent flake into the REPL:

```bash
$ nix repl github:NixOS/nixpkgs/23.11
```

In both cases the REPL would now have the `lib`, `checks`, `htmlDocs`, `legacyPackages`, and `nixosModules` attributes in scope since those are the attributes returned by the `outputs` function:

```bash
nix-repl> legacyPackages.x86_64-linux.hello
«derivation /nix/store/zjh5kllay6a2ws4w46267i97lrnyya9l-hello-2.12.1.drv»
```

This `legacyPackages.x86_64-linux.hello` attribute path is the same attribute path that our original flake output uses:

```nix
{ …

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
                                          # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  };
}
```

There's actually one more thing you can do with a flake, which is to access the original path to the flake.  The following flake shows an example of this feature in action:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        config = { };

        overlay = self: super: {
          hello = super.hello.overrideAttrs (_: { doCheck = false; });
        };

        overlays = [ overlay ];

        pkgs = import nixpkgs { inherit system config overlays; };
      in
        { packages.default = pkgs.hello; }
    );
}
```

This flake customizes Nixpkgs using an overlay instead of using the "stock" package set, but in order to create a new package set from that overlay we have to `import` the original source directory for Nixpkgs.  In the above example, that happens here when we `import` `nixpkgs`:

```nix
        pkgs = import nixpkgs { inherit system config overlays; };
```

Normally the `import` keyword expects either a file or (in this case) a directory containing a `default.nix` file, but here `nixpkgs` is neither: it's an attribute set containing all of the `nixpkgs` flake's outputs.  However, the `import` keyword can still treat `nixpkgs` like a path because it also comes with an `outPath` attribute, so we could have also written:

```nix
        pkgs = import nixpkgs.outPath { inherit system config overlays; };
```

All flake inputs come with this `outPath` attribute, meaning that you can use a flake input anywhere Nix expects a path and the flake input will be replaced with the path to the directory containing the `flake.nix` file.


### Platforms

All of the above examples hard-coded a single system (`x86_64-linux`), but usually you want to support building a package for multiple systems.  People typically use the `flake-utils` flake for this purpose, which you can use like this;

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = nixpkgs.legacyPackages."${system}".hello;
    });
}
```

… and that is essentially the same thing as if we had written:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-linux.default = nixpkgs.legacyPackages.aarch64-linux.hello;
    packages.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;
  };
}
```

We'll be using `flake-utils` throughout the rest of this chapter and you'll see almost all flakes use this, too.

## Flake-related commands

The Nix command-line interface provides several commands that are flake-aware, and for the purpose of this chapter we'll focus on the following commands:

- `nix build`
- `nix run`
- `nix shell`
- `nix develop`
- `nix flake check`
- `nix flake init`
- `nix eval`
- `nix repl`
- `nixos-rebuild`

We'll be using the following flake as the running example for our commands:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.8?dir=templates/cowsay'
```

… which will have this structure:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, self }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { packages.default = pkgs.cowsay;

          apps = …;

          checks = …;

          devShells = …;
        }) // {
          templates.default = …;
        };
}
```

One of the things you might notice is that the some of the output attributes are nested inside of the call to `eachDefaultSystem`.  Specifically, the `packages`, `apps`, `checks`, and `devShells` outputs:

```nix
    …

    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { packages.default = pkgs.cowsay;

          apps = …;

          checks = …;

          devShells = …;
        }) // …
```

For each of these outputs we want to generate system-specific build products, which is why they go inside the call to `eachDefaultSystem`.  However, some flake outputs (like templates) are not system-specific, so they would go outside of the call to `eachDefaultSystem`, like this:

```nix
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { …
        }) // {
          templates.default = …;
        };
```

You can always consult the [flake output schema](https://nixos.wiki/wiki/Flakes#Output_schema) if you're not sure which outputs are system-specific and which ones are not.  For example, the sample schema will show something like this:

```nix
self, ... }@inputs:
{ checks."<system>"."<name>" = derivation;
  …
  packages."<system>"."<name>" = derivation;
  …
  apps."<system>"."<name>" = {
    type = "app";
    program = "<store-path>";
  };
  …
  devShells."<system>"."<name>" = derivation;
  …
  templates."<name>" = {
    path = "<store-path>";
    description = "template description goes here?";
  };
}
```

… and `."<system>".` component of the first four attribute paths indicates that these outputs are system-specific, whereas the `templates."<name>"` attribute path has no system-specific path component.

The same sample schema also explains which outputs are used by which Nix commands, but we're about to cover that anyway:

### `nix build`

The `nix build` command builds output attributes underneath the `packages` attribute path.

For example, if we run:

```bash
$ nix build
```

… that will build the `.#packages."${system}".default` output, which in our flake is just a synonym for the `cowsay` package from Nixpkgs:

```nix
…
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { packages.default = pkgs.cowsay;

          …
        })
```

That build will produce this result:

```
$ tree ./result
./result
├── bin
│   ├── cowsay
│   └── cowthink -> cowsay
└── share
    └── cowsay
        ├── cows
        │   ├── DragonAndCow.pm
        │   ├── Example.pm
        │   ├── Frogs.pm
        │   ├── …
        │   ├── vader-koala.cow
        │   ├── vader.cow
        │   └── www.cow
        └── site-cows

5 directories, 58 files
```

… which we can run like this:

```bash
$ ./result/bin/cowsay howdy
 _______ 
< howdy >
 ------- 
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||

```

So far this isn't very interesting because we can already build the `cowsay` executable from Nixpkgs directly like this:

```bash
$ nix build 'github:NixOS/nixpkgs/23.11#cowsay'  # Exact same result
```

In fact, we don't even need to create a local copy of the `cowsay` template flake.  We could also have run the flake directly from the GitHub repository where it's hosted:

```bash
$ nix build 'github:Gabriella439/nixos-in-production/0.8?dir=templates/cowsay'
```

This works because flakes support GitHub URIs, so all of the flake operations in this chapter work directly on the GitHub repository without having to clone or template the repository locally.  However, for simplicity all of the following examples will still assume you templated the flake locally.

### `nix run`

Typically we won't run the command by building it and then running it.  Instead, we'll more commonly use `nix run` to do both in one go:

```bash
$ nix run . -- howdy  # The "." is necessary if the command takes arguments
 _______ 
< howdy >
 ------- 
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

… and if we wanted to we could run `cowsay` directly from Nixpkgs, too:

```bash
$ nix run 'github:NixOS/nixpkgs/23.11#cowsay' -- howdy  # Exact same result
```

By default, `nix run` will expand out `.` to `.#apps.${system}.default`, falling back to `.#packages.${system}.default` if that's not present.  Our flake happens to provide the former attribute path:

```nix
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { packages.default = pkgs.cowsay;

          apps = {
            default = self.apps."${system}".cowsay;

            cowsay = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowsay";
            };

            cowthink = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowthink";
            };
          };

          …
        }
```

This time our flake has three available apps (`default`, `cowsay`, and `cowthink`) and the `default` app is just a synonym for the `cowsay` app.  Each app has to have:

- a field named `type` whose value must be `"app"`

  Nix flakes don't support other types of apps, yet.

- a string containing the desired program to run

  This string cannot contain any command-line options.  It can only be a path to an executable.

Notice that flake outputs can reference other flake outputs (via the `self` flake input).  All flakes get this `self` flake input for free.  We could have also used the `rec` language keyword instead, like this:

```nix
          apps = rec {
            default = cowsay;
            
            cowsay = {
              type = "app";
              
              program = "${self.packages."${system}".default}/bin/cowsay";
            };
          
            cowthink = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowthink";
            };
          };
```

… which would define the `default` attribute to match the `cowsay` attribute within the same record.  This works in small cases, but doesn't scale well to more complicated cases; you should prefer using the `self` input to access other attribute paths.

You can use output attributes other than the `default` one by specifying their attribute paths.  For example, if we want to use the `cowthink` program then we can run:

```bash
$ nix run .#cowthink -- howdy
 _______ 
< howdy >
 ------- 
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

{blurb, class:information}
Apparently, the `cowthink` program produces the exact same result as the `cowsay` program.
{/blurb}

Since the `cowthink` app is indistinguishable from the `cowsay` app, let's replace it with a more interesting `kittysay` app that automatically adds the `-f hellokitty` flag.  However, we can't do something like this:

```nix
          apps = {
            …

            kittysay = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowsay -f hellokitty";
            };
          };
```

If you try to do that you'll get an error like this one:

```bash
$ nix run .#kittysay -- howdy
error: unable to execute '/nix/store/…-cowsay-3.7.0/bin/cowsay -f hellokitty': No such file or directory
```

… because Nix expects the `program` attribute to be an executable path, not including any command-line arguments.  If you want to wrap an executable with arguments then you need to do something like this:

```nix
        { packages = {
            default = pkgs.cowsay;

            kittysay = pkgs.writeScriptBin "kittysay"
              ''
              ${self.packages."${system}".default}/bin/cowsay -f hellokitty "$@";
              '';
          };

          apps = {
            …

            kittysay = {
              type = "app";

              program = "${self.packages."${system}".kittysay}/bin/kittysay";
            };
          };
```

Here we define a `kittysay` package (which wraps `cowsay` with the desired command-line option) and a matching `kittysay` app.

Note that if the name of the app is the same as the default executable for a package then we can just omit the app entirely.  In the above `kittysay` example, we could delete the `kittysay` app and the example would still work because Nix will fall back to running `${self.packages.${system}.kittysay}/bin/kittysay`.  You can use `nix run --help` to see the full set of rules for how Nix decides what attribute to use and what path to execute.

### `nix shell`

If you plan on running the same command (interactively) over and over then you probably don't want to have to type `nix run` before every use of the command.  Not only is this less ergonomic but it's also slower since the flake has to be re-evaluated every time you run the command.

The `nix shell` comes in handy for use cases like this where it will take the flake outputs that you specify and add them to your executable search path (e.g. your `$PATH` in `bash`) for ease of repeated use.  We can add our `cowsay` to our search path in this way:

```bash
$ nix shell
$ cowsay howdy
 _______ 
< howdy >
 ------- 
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

`nix shell` creates a temporary subshell providing the desired commands and you can exit from this subshell by entering an `exit` command or typing `Ctrl-D`.

`nix shell` can be useful for pulling in local executables from your flake, but it's even more useful for pulling in executables temporarily from Nixpkgs (since Nixpkgs provides a large array of useful programs).  For example, if you wanted to temporarily add `vim` and `tree` to your shell you could run:

```bash
$ nix shell 'github:NixOS/nixpkgs/23.11#'{vim,tree}
```

{blurb, class:information}
Note that the `{vim,tree}` syntax in the previous command is a Bash/Zsh feature.  Both shells expand the previous command to:

```bash
$ nix shell 'github:NixOS/nixpkgs/23.11#vim' 'github:NixOS/nixpkgs/23.11#tree'
```

This feature is a convenient way to avoid having to type out the `github:NixOS/nixpkgs/23.11` flake reference twice when adding multiple programs to your shell environment.
{/blurb}

### `nix develop`

You can even create a reusable development shell if you find yourself repeatedly using the same temporary executables.  Our sample flake illustrates this by providing two shells:

```nix
          devShells = {
            default = self.packages."${system}".default;

            with-dev-tools = pkgs.mkShell {
              inputsFrom = [ self.packages."${system}".default ];

              packages = [
                pkgs.vim
                pkgs.tree
              ];
            };
          };
```

You can enter the `default` shell by running:

```bash
$ nix develop
```

… which will expand out to `.#devShells.${system}.default`, falling back to `.#packages.${system}.default` if the former attribute path is not present.  This will give us a development environment for building the `cowsay` executable.  You can use these `devShells` to create reusables development environments (for yourself or others) so that you don't have to build up large `nix shell` commands.

{blurb, class:information}
You can exit from this development shell by either entering `exit` or typing `Ctrl-D`.
{/blurb}

You might wonder what's the difference between `nix develop` and `nix shell`.  The difference between the two is that:

- `nix shell` adds the specified programs to your executable search `PATH`

- `nix develop` adds the *development dependencies of the specified programs* to your executable search `PATH`

As a concrete example, when you run:

```bash
$ nix shell nixpkgs#vim
```

That adds `vim` to your executable search path.  In contrast, if you run:

```bash
$ nix develop nixpkgs#vim
```

That provides a *development environment* necessary to build the `vim` executable (like a C compiler or the `ncurses` package), but does not provide `vim` itself.

In our sample flake, we used the `mkShell` utility:

```nix
            with-dev-tools = pkgs.mkShell {
              inputsFrom = [ self.packages."${system}".default ];

              packages = [
                pkgs.vim
                pkgs.tree
              ];
            };
```

… which is a convenient way to create a synthetic development environment (appropriate for use with `nix develop`).

The two most common arguments to `mkShell` are:

- `inputsFrom`

  `mkShell` inherits the development dependencies of any package that you list here.  Since `self.packages."${system}".default` is just our `cowsay` package then that means that all development dependencies of the `cowsay` package also become development dependencies of `mkShell`.

- `packages`

  All packages listed in the `packages` argument to `mkShell` become development dependencies of `mkShell`.  So if we add `vim` and `tree` here then those will be present on the executable search path of our synthetic environment if we call `nix develop` on our `mkShell`.

This means that the `with-dev-tools` shell is essentially the same as the `default` shell, except also extended with the `vim` and `tree` packages added to the executable search path.

### `nix flake check`

You can add tests to a flake that the `nix flake check` command will run.  These tests go under the `checks` output attribute and our sample flake provides a simple functional test for the `cowsay` package:

```nix
          checks = {
            default = self.packages."${system}".default;

            diff = pkgs.runCommand "test-cowsay" { }
              ''
              diff <(${self.apps."${system}".default.program} howdy) - <<'EOF'
               _______ 
              < howdy >
               ------- 
                      \   ^__^
                       \  (oo)\_______
                          (__)\       )\/\
                              ||----w |
                              ||     ||
              EOF

              touch $out
              '';
          };
```

The `default` check is a synonym for our `cowsay` package and just runs `cowsay`'s (non-existent) test suite.  The `diff` check is a functional test that compares some sample `cowsay` output against a golden result.

We can run both checks (the `default` check and the `diff` check) using:

```bash
$ nix flake check
```

The `nix flake check` command also performs other hygiene checks on the given flake and you can learn more about the full set of checks by running:

```bash
$ nix flake check --help
```

### `nix flake init`

You can template a project using `nix flake init`, which we've already used a few times throughout this book (including this chapter).  Our `cowsay` flake contains the following `templates` output:

```nix
        }) // {
          templates.default = {
            path = ./.;

            description = "A tutorial flake wrapping the cowsay package";
          };
        };
```

… so earlier when we ran:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.8?dir=templates/cowsay'
```

… that copied the directory pointed to by the `templates.default.path` flake output to our local directory.

Note that this flake output is not system-specific, which is why it's not nested inside the call to `eachDefaultSystems` in our flake.  This is because there's nothing system-dependent about templating some text files.

### `nix eval`

`nix eval` is another command we've already used a few times throughout this book to query information about our flakes without building anything.  For example, if we wanted to query the version of our `cowsay` package, we could run:

```bash
$ nix eval '.#default.version'
"3.7.0"
```
This is because flake outputs are "just" attribute sets and Nix derivations are also "just" attribute sets, so we can dig into useful information about them by accessing the appropriate attribute path.

However, you might not necessarily know what attribute paths are even available to query, which brings us to the next extremely useful Nix command:

### `nix repl`

You can use the `nix repl` command to easily interactively explore what attributes are available using REPL auto-completion.  For example, if you run:

```bash
$ nix repl .  # This requires the `repl-flake` experimental feature
```

That will load all of the flake outputs (e.g. `packages`, `apps`, `checks`, `devShells`, `templates`) as identifiers of the same name into the REPL.  Then you can use tab completion to dig further into their available fields:

```
nix-repl> pac<TAB>

nix-repl> packages.<TAB>
packages.x86_64-linux  packages.i686-linux      packages.x86_64-linux
packages.aarch64-linux   packages.x86_64-darwin

nix-repl> packages.x86_64-linux.<TAB>

nix-repl> packages.x86_64-linux.default.<TAB>
packages.x86_64-linux.default.__darwinAllowLocalNetworking
packages.x86_64-linux.default.__ignoreNulls
packages.x86_64-linux.default.__impureHostDeps
…
packages.x86_64-linux.default.updateScript
packages.x86_64-linux.default.userHook
packages.x86_64-linux.default.version

nix-repl> packages.x86_64-linux.default.version
"3.7.0"
```

Remember that `flake-utils` (specifically the `eachDefaultSystem` function) adds system attributes underneath each of these top-level attributes, so even though we don't explicitly specify system attribute in our `flake.nix` file they're still going to be there when we navigate the flake outputs in the REPL.  That's why we have to specify `packages.x86_64-linux.default.version` in the REPL instead of just `packages.default.version`.

However, you can skip having to specify the system if you specify the package you want to load into the REPL.  For example, if we load the `default` package output like this:

```bash
$ nix repl .#default
```

… that's the same as loading `.#packages.${system}.default` into the REPL, meaning that all of the `default` package's attributes are now top-level identifiers in the REPL, including `version`:

```bash
nix-repl> version
"3.7.0"
```

The `nix repl` command comes in handy if you want to explore Nix code interactively, whereas the `nix eval` command comes more in handy for non-interactive use (e.g. scripting).

### `nixos-rebuild`

Last, but not least, the `nixos-rebuild` command also accepts flake outputs that specify the system to deploy.  We already saw an example of this in the [Deploying to AWS using Terraform](#terraform) chapter where we specified our system to deploy as `.#default` which expands out to the `.#nixosConfigurations.default` flake output.

Similar to the `templates` flake outputs, `nixosConfigurations` are not system-specific.  There's no particular good reason why this is the case since NixOS can (in theory) be built for multiple systems (e.g. `x86_64-linux` or `aarch64-linux`), but in practice most NixOS systems are only defined for a single architecture.

Our sample `cowsay` flake doesn't provide any `nixosConfigurations` output, but the flake
from our [Terraform](#terraform) chapter has an example `nixosConfigurations` output.
