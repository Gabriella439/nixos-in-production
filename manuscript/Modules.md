# The module system under the hood

Alright, so by this point you've copied, pasted, and ran a whole bunch of NixOS code, but perhaps you don't fully understand what is going on, especially if you're not an experienced NixOS user.  This chapter will slow down and help you solidify your understanding of the NixOS module system so that you can better understand how to read, author, and debug modules.

## Anatomy of a NixOS module

In the most general case, a NixOS module has the following "shape":

```nix
# Module arguments which our module can use to refer to its own configuration
{ config, lib, pkgs, ... }:

{ # Other modules to import
  imports = [
    …
  ];

  # Options that this module declares
  #
  # e.g. option names and their descriptions, types, default values
  options = {
    …
  };

  # Options that this module sets
  #
  # … which could have been defined in other modules
  config = {
    …
  };
}
```

In other words, in the fully general case a NixOS module is a function whose output is an attribute set with three attributes named `imports`, `options`, and `config`.

{blurb, class:information}
Nix provides data structures known "attribute sets" which double as both "maps" and "records".

"Maps" are also known "dictionaries"/"dicts" (in Python), "hashmaps"/"hashes" (in Ruby), or "associative arrays" (in Bash).  All of these data structures share the following properties in common:

- the keys might be dynamic
- the values usually share the same type

"Records" are more commonly known as "structs" (in C), or "data classes" (in Java).  These data structures also represent some mapping from keys to values where:

- the keys are static
- the values might differ in type

Typed languages (like Haskell or Rust) typically distinguish between homogeneous and heterogeneous maps whereas weakly-typed languages (like Clojure or Ruby) commonly use the same data structure for both.  Nix is a weakly-typed language so Nix also the same data structure ("attribute sets") to represent both maps and records.

This book usually won't explain the Nix programming language in this much detail, but I'll use the terms "attribute set" and "attribute" consistently throughout the text to match Nix's official terminology (even though no other language uses those terms), so I felt that this was worth explaining.
{/blurb}

All elements of a NixOS module are optional.  For example, you can omit the module arguments if you don't use them:

```nix
{ imports = [
    …
  ];

  options = {
    …
  };

  config = {
    …
  };
}
```

You can also omit any of the `imports`, `options`, or `config` attributes if you don't use them.  For example, you can have an `imports`-only module:

```nix
{ imports = [
    ./physical.nix
    ./logical.nix
  ];
}
```

… or a `config`-only module:

```nix
{ config = {
    services = {
      apache-kafka.enable = true;

      zookeeper.enable = true;
    };
  };
}
```

Moreover, the NixOS module system provides special support for `config`-only modules by letting you elide the `config` attribute and promote the attributes nested within to the "top level", like this:

```nix
{ services = {
    apache-kafka.enable = true;

    zookeeper.enable = true;
  };
}
```

{blurb, class:information}
You might wonder if you should enforce some sort of coding style for your organization which specifies whether people can omit these elements of a NixOS module.  For example, perhaps you might require that all elements are present, for consistency, even if they are empty or unused.

My recommendation is:

- you should permit omitting the module arguments

- you should permit omitting the `imports`, `options`, or `config` attributes

- you should *not* permit eliding the `config` attribute

  In other words, if you do set any options, always nest them underneath the `config` attribute.
{/blurb}

## NixOS modules are not language features

The Nix programming language does not provide any built-in support for NixOS modules.  This sometimes confuses people new to either the Nix programming language or the NixOS module system.

The NixOS module system is a domain-specific language implemented within the Nix programming language.  Specifically, the NixOS modules system is (mostly) implemented within the [`lib/modules.nix` file included in Nixpkgs](https://search.nixos.org/options).  If you ever receive a stack trace related to the NixOS module system you will often see functions from `modules.nix` show up in the stack track, because they are ordinary functions and not language features.

In fact, a NixOS module in isolation is essentially "inert" from the Nix language's point of view.  For example, if you save the following NixOS module to a file named `example.nix`:

```nix
{ config = {
    services.openssh.enable = true;
  };
}
```

… and you evaluate that, the output will be the exact same attribute set as the input, just without the syntactic sugar:

```bash
$ nix eval --file ./example.nix
{ config = { services = { openssh = { enable = true; }; }; }; }
```

{blurb, class:information}
The Nix programming language provides "syntactic sugar" for compressing nested attributes by chaining them using `.`.  In other words, this Nix expression:

```nix
{ config = {
    services.openssh.enable = true;
  };
}

… is the same thing as this Nix expression:

```nix
{ config = {
    services = {
      openssh = {
        enable = true;
      };
    };
  };
}
```

… and they are both also the same thing as this Nix expression:

```nix
{ config.services.openssh.enable = true; }
```

Note that this syntactic sugar is a feature of the *Nix programming language*, not the NixOS module system.  In other words, this feature works even for Nix expressions that are not destined for use as NixOS modules.
{/blurb}

Along the same lines, the following NixOS module:

```nix
{ config, ... }:

{ config = {
    services.apache-kafka.enable = config.services.zookeeper.enable;
  };
}
```

… is just a function.  If we save that to `example.nix` and evaluate that the interpreter will only say that it evaluates to a "lambda" (an anonymous function):

```bash
$ nix eval --file ./example.nix
<LAMBDA>
```

… but we can get a more useful within the `nix repl` by calling our function on a sample argument:

```bash
$ nix repl
Welcome to Nix 2.11.0. Type :? for help.

nix-repl> example = import ./example.nix

nix-repl> input = { config = { services.zookeeper.enable = true; }; }

nix-repl> output = example input

nix-repl> :p output
{ config = { services = { apache-kafka = { enable = true; }; }; }; }

nix-repl> output.config.services.apache-kafka.enable
true
```

This illustrates that our NixOS module really is just a function whose input is an attribute set and whose output is also an attribute set.  Once we call our `example` function on a sample `input` attribute set we get back a sample `output` attribute set.

## The NixOS module system

So if NixOS modules are just pure functions or pure values, what turns those Nix expressions into a useful operating system?

This actually happens in two steps:

- All of the NixOS modules are combined into a single, composite attribute set 

  In other words all of the `imports`, `options` declarations, and `config` settings are fully resolved, resulting in one giant attribute set.  The code for combining these modules lives in [`lib/modules.nix`](https://search.nixos.org/options) in Nixpkgs.

- The final attribute set contains a special attribute that builds the system

  Specifically, there is a `config.system.build.toplevel` attribute path which contains a derivation you can use to build a runnable NixOS system.  The top-level code for assembling an operating system lives in [`nixos/modules/system/activation/top-level.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/activation/top-level.nix) in Nixpkgs.


This might make more sense if we use the NixOS module system ourselves to create a fake placeholder value that will stand in for a real operating system.

First, we'll create our own fake `top-level.nix` module that will create a fake
`config.system.build.toplevel` attribute path that is a string instead of a derivation for building an operating system:

```nix
# top-level.nix

{ config, lib, ... }:

{ imports = [ ./other.nix ];

  options = {
    system.build.toplevel = lib.mkOption {
      description = "A fake NixOS, modeled as a string";

      type = lib.types.str;
    };
  };

  config = {
    system.build.toplevel =
      "Fake NixOS - version ${config.system.nixos.release}";
  };
}
```

That imports another `other.nix` module which we'll also create:

```nix
# other.nix

{ lib, ... }:

{ options = {
    system.nixos.release = lib.mkOption {
      description = "The NixOS version";

      type = lib.types.str;
    };
  };

  config = {
    system.nixos.release = "22.05";
  };
}
```

We can then materialize the final composite attribute set like this:

```bash
$ nix repl github:NixOS/nixpkgs/22.05
Welcome to Nix 2.11.0. Type :? for help.

Loading installable 'github:NixOS/nixpkgs/22.05#'...
Added 5 variables.
nix-repl> result = lib.evalModules { modules = [ ./top-level.nix ]; }

nix-repl> :p result.config
{ system = { build = { toplevel = "Fake NixOS - version 22.05"; }; nixos = { release = "22.05"; }; }; }

nix-repl> result.config.system.build.toplevel
"Fake NixOS - version 22.05"
```

In other words, `lib.evalModules` is the magic function that combines all of our NixOS modules into a composite attribute set.

NixOS essentially does the same thing as in the above example, except on a much larger scale and also the `config.system.build.toplevel` attribute is a derivation instead of a string.

## Recursion

One feature of the NixOS module system is that modules can refer to the final composite configuration using the `config` function argument that is passed in to every NixOS module.  For example, this is how our `top-level.nix` module was able to refer to the `system.nixos.release` option that was set in the `other.nix` module:

```nix
# This stores the final composite configuration
# ↓
{ config, lib, ... }:

{ …

  config = {
    system.build.toplevel =
      "Fake NixOS - version ${config.system.nixos.release}";
                            # ↑
                            # … which we can within our own configuration
  };
}
```

A NixOS module can even refer to its own configuration values (which is a form of [recursion](https://en.wikipedia.org/wiki/Recursion)).  For example, suppose we were to merge the `other.nix` module into the `top-level.nix` module:

```nix
{ config, lib, ... }:

{ options = {
    system.build.toplevel = lib.mkOption {
      description = "A fake NixOS, modeled as a string";

      type = lib.types.str;
    };

    system.nixos.release = lib.mkOption {
      description = "The NixOS version";

      type = lib.types.str;
    };
  };

  config = {
    system.build.toplevel =
      "Fake NixOS - version ${config.system.nixos.release}";

    system.nixos.release = "22.05";
  };
}
```

This would still work!   Even though this module recursively refers to its own configuration the Nix interpreter won't go into an infinite loop because the recursion is still well-founded: the `system.build.toplevel` refers to a different `system.nixos.release` attribute which has no further references.

We can build an even better intuition for how this works by simulating how `lib.evalModules` works by hand.  Conceptually what `lib.evalModules` does is:

- Combine all of the input modules

  … including resolving `imports`.  This creates a composite NixOS module similar to the above example where we merged `other.nix` into `top-level.nix`.


- Compute the [fixed point](https://en.wikipedia.org/wiki/Fixed_point_(mathematics)) of this composite module

  … by passing the output of the module as its own input.

We'll reason through this by performing the same steps as `lib.evalModules` by hand.  First, to simplify things we'll consolidate the prior example into a single flake that we can evaluate as we go:

```nix
# Save this to `./evalModules/flake.nix`

{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.05";

  outputs = { nixpkgs, ... }:
    let
      other =
        { lib, ... }:
        { # To save space, this example also compresses the code a bit
          options.system.nixos.release = lib.mkOption {
            description = "The NixOS version";
            type = lib.types.str;
          };
          config.system.nixos.release = "22.05";
        };


      topLevel =
        { config, lib, ... }:
        { imports = [ other ];
          options.system.build.toplevel = lib.mkOption {
            description = "A fake NixOS, modeled as a string";
            type = lib.types.str;
          };
          config.system.build.toplevel =
            "Fake NixOS - version ${config.system.nixos.release}";
        };

    in
      nixpkgs.lib.evalModules { modules = [ topLevel ]; };
}
```

You can evaluate the above flake like this:

```bash
$ nix eval ./evalModules#config
{ system = { build = { toplevel = "Fake NixOS - version 22.05"; }; nixos = { release = "22.05"; }; }; }

$ nix eval ./evalModules#config.system.build.toplevel 
"Fake NixOS - version 22.05"
```

The first thing that `lib.evalModules` does is to merge the `other` module into the `topLevel` module, which we will simulate by hand by pre-merging the `other` module into the `topLevel` module:

```nix
{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.05";

  outputs = { nixpkgs, ... }:
    let
      topLevel =
        { config, lib, ... }:
        { options.system.nixos.release = lib.mkOption {
            description = "The NixOS version";
            type = lib.types.str;
          };
          options.system.build.toplevel = lib.mkOption {
            description = "A fake NixOS, modeled as a string";
            type = lib.types.str;
          };
          config.system.nixos.release = "22.05";
          config.system.build.toplevel =
            "Fake NixOS - version ${config.system.nixos.release}";
        };

    in
      nixpkgs.lib.evalModules { modules = [ topLevel ]; };
}
```

The last step is that we compute the fixed point of our module (which is a function) by passing the module's output as its own input, the same way that `evalModules` would:

```nix
{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.05";

  outputs = { nixpkgs, ... }:
    let
      topLevel =
        { config, lib, ... }:
        { options.system.nixos.release = lib.mkOption {
            description = "The NixOS version";
            type = lib.types.str;
          };
          options.system.build.toplevel = lib.mkOption {
            description = "A fake NixOS, modeled as a string";
            type = lib.types.str;
          };
          config.system.nixos.release = "22.05";
          config.system.build.toplevel =
            "Fake NixOS - version ${config.system.nixos.release}";
        };

      result = topLevel {
        inherit (result) config options;
        inherit (nixpkgs) lib;
      };

    in
      result;
}
```

{blurb, class:information}
The above example is a gross oversimplification of what `evalModules` does.  For starters, we've completely ignored how `evalModules` uses the `options` declarations to:

- check that configuration values match their declared types
- replace missing configuration values with their default values

However, this oversimplification lets us better understand how the NixOS module system correctly handles a module referencing its own configuration.
{/blurb}

The last step is that when `nix eval` accesses the `config.system.build.toplevel` field of the `result`, the Nix interpreter conceptually performs the following substitutions:

```nix
result.config.system.build.toplevel
```

```nix
# Substitute `result` with its right-hand side
= (topLevel {
    inherit (result) config options;
    inherit (nixpkgs) lib;
  }).config.system.build.toplevel
```

```nix
# `inherit` is syntactic sugar for this equivalent Nix expression
= ( topLevel {
      config = result.config;
      options = result.options;
      lib = nixpkgs.lib;
    }
  ).config.system.build.toplevel
```

```nix
# Evaluate the `topLevel` function
= ( { options.system.nixos.release = lib.mkOption {
        description = "The NixOS version";
        type = lib.types.str;
      };
      options.system.build.toplevel = lib.mkOption {
        description = "A fake NixOS, modeled as a string";
        type = lib.types.str;
      };
      config.system.nixos.release = "22.05";
      config.system.build.toplevel =
        "Fake NixOS - version ${result.config.system.nixos.release}";
    }
  ).config.system.build.toplevel
```

```nix
# Access the `config.system.build.toplevel` attribute path
= "Fake NixOS - version ${result.config.system.nixos.release}"
```

```nix
# Substitute `result` with its right-hand side (again)
= "Fake NixOS - version ${
  (topLevel {
      inherit (result) config options;
      inherit (nixpkgs) lib;
    }
  ).config.system.nixos.release
}"
```

```nix
# Evaluate the `topLevel` function (again)
= "Fake NixOS - version ${
  ( { options.system.nixos.release = lib.mkOption {
        description = "The NixOS version";
        type = lib.types.str;
      };
      options.system.build.toplevel = lib.mkOption {
        description = "A fake NixOS, modeled as a string";
        type = lib.types.str;
      };
      config.system.nixos.release = "22.05";
      config.system.build.toplevel =
        "Fake NixOS - version ${result.config.system.nixos.release}";
    }
  ).config.system.nixos.release
}"
```

```nix
# Access the `config.system.nixos.release` attribute
= "Fake NixOS - version ${"22.05"}"

# Evaluate the string interpolation
= "Fake NixOS - version 22.05"
```

So even though our NixOS module is recursive, that recursion is still well-founded and produces an actual result.
