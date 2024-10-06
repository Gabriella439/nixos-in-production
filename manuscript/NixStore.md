# The Nix store

Through this book we've only interacted with the Nix ecosystem through two interfaces:

- the Nix expression language

  Think: `.nix` files.  This is the Nix source code that we edit to define our flakes and NixOS configurations that we build and deploy.


- the Nix command-line interface

  In other words, the `nix` command-line tool and its subcommands.

However, we've glossed over an important implementation detail of how all of the Nix tooling works, which is the Nix store.  The only clue so far that the Nix store exists is various log messages or error messages that display long filepaths whose names begin with `/nix/store/…`, like this:

```
copying path '/nix/store/ayaymfnf7mrwv9v9a7jkajggy2lw13w8-libavif-0.11.1' from 'https://cache.nixos.org'...
copying path '/nix/store/igzabwg6mivj9j4cbkd570mws0haj9n7-gd-2.3.3' from 'https://cache.nixos.org'...
building '/nix/store/0nq1q1dfq97r7zp6mm9zmcn89v79aqaf-ensure-all-wrappers-paths-exist.drv'...
copying path '/nix/store/9iiqv6c3q8zlsqfp75vd2r7f1grwbxh7-nginx-1.24.0' from 'https://cache.nixos.org'...
building '/nix/store/9vn8j8gw99zp2fiqnbnfvy7c8jbicma3-etc-os-release.drv'...
building '/nix/store/pa40bsjxs7wjhvhp5r6w4549gc3qnrrl-firewall-start.drv'...
```

You don't really need to understand how the Nix store works on the happy path (if nothing goes wrong), but if things break or you need to do something weird or fancy then you will probably need a better understanding of the Nix store.  This chapter will dive into the Nix store and cover the most important concepts and commands you need to effectively work with the store.

## Introduction

So what *is* the Nix store?

The most important part of the Nix store is the `/nix/store` directory[^1], which stores two types of things:

- Derivations

  Derivations are files that end with a `.drv` extension that are stored inside of the `/nix/store` directory.  For example, the name of a derivation might be something like `/nix/store/mlvp9pl1k8a014iqvmfihcpi3xgas01c-hello-2.12.1.drv`.

  Derivations represent language-agnostic instructions for how to create build products.


- Build products

  All of the other paths inside of the `/nix/store` (the ones that don't end with `.drv`) are build products.

  These paths can be individual files (like `/nix/store/z37qsb6fnzyicmq26342lfqdssjjl5aa-fix-diff-D.patch`) or directories (like `/nix/store/7b0rz3bnx7msw2wawkv1hhn5lqf1b0wi-python3-3.11.6/`).

You might wonder: what is the deal with derivations?  What purpose do they serve?  Why does Nix store derivations inside the Nix store alongside build products?

## Derivations

You can think of derivations as an intermediate representation in Nix's build pipeline, which has three stages:

- the Nix expression language

  This is the Nix source code stored in `.nix` files that users are expected to edit and interact with.

  You can think of Nix expressions as the "frontend" for the Nix programming language.


- derivation files

  Nix source code is converted to `.drv` files stored inside the `/nix/store` directory.  These derivation files do **NOT** store Nix source code, but rather they store plain/inert data.  In case you are curious, the file format derivations use is ATerm, but this is an even more obscure implementation detail.  The Nix command-line interface converts derivation files to JSON when displaying them to end users so you can safely ignore the fact that they are stored as ATerm values.

  You can think of derivations as the "backend" for the Nix programming language but also the "frontend" for the Nix store.

- Nix build products

  These are the executables, directories, and files we build with Nix.

  You can think of build products as the "backend" for the Nix store.

The process of converting a Nix expression to a derivation is called "instantiation" and the process of converting a derivation to a build product is called "realization".  This means that a complete Nix build has two steps: instantiation + realization:

![](./pipeline.png)

The Nix programming language and the Nix store work together to provide the complete build pipeline and derivations are the interface between the two.

{blurb, class:information}
You can think of the "Nix store" as more of a service rather than a store.  Most Nix experts who use the phrase "Nix store" are referring not just to the repository of derivations and build products but all of the supporting infrastructure (like the Nix daemon and Nix command-line interface) that converts derivations to build products.

The reason for this separation of responsibilities is so that you can (in principle) swap out the front-end language and replace the Nix programming language with a different language if you don't like Nix while still getting all the nice feature of the Nix store like caching, remote builds, and closure management.  In fact, if you're a company with an existing build tool that is showing its age you might consider swapping out your tool's backend with the Nix store while keeping your existing frontend the same.  This is outside the scope of this book, though.

In fact, this is not a hypothetical scenario: [Guix](https://guix.gnu.org/) works this way.  Guix is sort of based on the Nix store[^2], but replaces the frontend language with Guile Scheme.  Any language that can generate derivation files can interoperate with the Nix store.
{/blurb}

For example, when we build something like this:

```bash
$ nix build --print-out-paths 'github:NixOS/nixpkgs/23.11#hello'
/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1
```

… we can do the same thing in two separate steps.  First, we instantiate the Nix expression, like this:

```bash
$ nix path-info --derivation 'github:NixOS/nixpkgs/23.11#hello'
/nix/store/mlvp9pl1k8a014iqvmfihcpi3xgas01c-hello-2.12.1.drv
```

… and then we realise that derivation (also using `nix build`, but note the `^*` at the end):

```bash
$ nix build --print-out-paths '/nix/store/mlvp9pl1k8a014iqvmfihcpi3xgas01c-hello-2.12.1.drv^*'
/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1
```

You can also take a look at the intermediate derivation using `nix derivation show`:

```bash
$ nix derivation show 'github:NixOS/nixpkgs/23.11#hello'
```
```json
{
  "/nix/store/mlvp9pl1k8a014iqvmfihcpi3xgas01c-hello-2.12.1.drv": {
    "args": [
      "-e",
      "/nix/store/v6x3cs394jgqfbi0a42pam708flxaphh-default-builder.sh"
    ],
    …
    "name": "hello-2.12.1",
    "outputs": {
      "out": {
        "path": "/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1"
      }
    },
    "system": "aarch64-darwin"
  }
}
```

The result can sometimes be a bit big, but we'll focus on the `path` field for right now.  Notice how the field's value (`/nix/store/d5pw3xm…`) matches the final build product we got.  In fact, Nix decides in advance (at instantiation time) where the build product goes before it is even built (at realization time).  To see why, consider this example flake:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

      in
        { packages.default = pkgs.runCommand "example" { } ''
            ${pkgs.hello}/bin/hello > "$out"
          '';
        });
}
```

If we save that to `flake.nix` and inspect the derivation then we'll see something like this:

```bash
$ nix derivation show '.#'
```
```json
{
  "/nix/store/jiv878lap59xlihiyma9hkipzcqjkfgp-example.drv": {
    …
    "env": {
      …
      "buildCommand": "/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1/bin/hello > \"$out\"\n",
      …
    },
    …
  }
}
```

Nix needs to know the path to the built `hello` package (i.e. `/nix/store/d5pw3xm…`) *before it has been built* so that it can generate the derivation for the downstream `example` package.

### Derivation format

Let's do a deeper dive into the derivation for the `hello` package to better understand what is going on under the hood.  This time I'll truncate less of the output:

```bash
$ nix derivation show 'github:NixOS/nixpkgs/23.11#hello' 
```
```json
{
  "/nix/store/mlvp9pl1k8a014iqvmfihcpi3xgas01c-hello-2.12.1.drv": {
    "args": [
      "-e",
      "/nix/store/v6x3cs394jgqfbi0a42pam708flxaphh-default-builder.sh"
    ],
    "builder": "/nix/store/x1xxsh1gp6y389hyl40a0i74dkxiprl7-bash-5.2-p15/bin/bash",
    "env": {
      …
      "out": "/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1",
      "outputs": "out",
      …
      "src": "/nix/store/pa10z4ngm0g83kx9mssrqzz30s84vq7k-hello-2.12.1.tar.gz",
      "stdenv": "/nix/store/sr62lps3id6rbasca3rp5inhrbkdrj1a-stdenv-darwin",
    },
    "inputDrvs": {
      "/nix/store/balbbdsww2g8ywsm8ls7xyfqdzh3az2x-bash-5.2-p15.drv": { … },
      "/nix/store/p2li3qgq3gpn7in5wz40dv1bppyygbr7-hello-2.12.1.tar.gz.drv": { … },
      "/nix/store/xxy6rfp2ixsbg7lqspjcp6ynmkjgzh4p-stdenv-darwin.drv": { … }
    },
    "inputSrcs": [
      "/nix/store/v6x3cs394jgqfbi0a42pam708flxaphh-default-builder.sh"
    ],
    "name": "hello-2.12.1",
    "outputs": {
      "out": {
        "path": "/nix/store/d5pw3xm4n9xqql53lmrbqhl04inx8dzp-hello-2.12.1"
      }
    },
    "system": "aarch64-darwin"
  }
}
```

All derivations have the following top-level fields:

[^1]: Technically the location of this directory is configurable using [the `store` `nix.conf` option](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-store) but the vast majority of Nix installations will use the default.  Moreover, you probably don't want to change the store path because then you can't use the public Nix cache or share build products with Nix stores that use a different store path.

[^2]: Guix technically uses a fork of the original Nix store, so unfortunately it won't interoperate with Nix's store.  This is partly because at the time Nix's store supported some features specific to the Nix programming language and Guix also wanted its store to support features specific to Guile Scheme.  In other words, both tools were guilty of "layer violations" although Nix has been steadily fixing its own layer violations.

TODO:

- Closures
  - Runtime
  - Buildtime
- GC roots
- `nix` commands
- `nix.conf` options (e.g. `auto-optimise-store` or `keep-{outputs,derivations}` or `min-free` / `max-free`)
