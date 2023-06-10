# NixOS option definitions

By this point in the book you may have copied and pasted some NixOS code, but perhaps you don't fully understand what is going on, especially if you're not an experienced NixOS user.  This chapter will slow down and help you solidify your understanding of the NixOS module system so that you can improve your ability to read, author, and debug modules.

{blurb, class:information}
Throughout this book I'll consistently use the following terminology to avoid ambiguity:

- "Option declarations" will refer to the `options` attribute of a NixOS module

- "Option definitions" will refer to the `config` attribute of a NixOS module

Along the same lines:

- "Declare an option" will mean to set an attribute nested underneath `options`

- "Define an option" will mean to set an attribute nested underneath `config`

In this chapter and the next chapter we'll focus mostly on option *definitions* and later on we'll cover option *declarations* in more detail.
{/blurb}

## Anatomy of a NixOS module

In the most general case, a NixOS module has the following "shape":

```nix
# Module arguments which our system can use to refer to its own configuration
{ config, lib, pkgs, ... }:

{ # Other modules to import
  imports = [
    …
  ];

  # Options that this module declares
  options = {
    …
  };

  # Options that this module defines
  config = {
    …
  };
}
```

In other words, in the fully general case a NixOS module is a function whose output is an attribute set with three attributes named `imports`, `options`, and `config`.

{blurb, class:information}
Nix supports data structures known "attribute sets" which are analogous to "maps" or "records" in other programming languages.

To be precise, Nix uses the following terminology:

- *an "attribute set" is a data structure associating keys with values*

  For example, this is a nested attribute set:

  ```nix
  { bio = { name = "Alice"; age = 24; };
    job = "Software engineer";
  }
  ```


- an "attribute" is Nix's name for a key or a field of an "attribute set"

  For example, `bio`, `job`, `name`, and `age` are all attributes in the above example.


- *an "attribute path" is a chain of one or more attributes separated by dots*

  For example, `bio.name` is an attribute path.

I'm explaining all of this because I'll use the terms "attribute set", "attribute", and "attribute path" consistently throughout the text to match Nix's official terminology (even though no other language uses those terms).
{/blurb}

## Syntactic sugar

All elements of a NixOS module are optional and NixOS supports "syntactic sugar" to simplify several common cases.  For example, you can omit the module arguments if you don't use them:

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

You can also omit any of the `imports`, `options`, or `config` attributes, too, like in this module, which only imports other modules:

```nix
{ imports = [
    ./physical.nix
    ./logical.nix
  ];
}
```

… or this `config`-only module:

```nix
{ config = {
    services = {
      apache-kafka.enable = true;

      zookeeper.enable = true;
    };
  };
}
```

Additionally, the NixOS module system provides special support for modules which only define options by letting you elide the `config` attribute and promote the options defined within to the "top level".  As an example, we can simplify the previous NixOS module to this:

```nix
{ services = {
    apache-kafka.enable = true;

    zookeeper.enable = true;
  };
}
```

{blurb, class:information}
You might wonder if there should be some sort of coding style which specifies whether people should include or omit these elements of a NixOS module.  For example, perhaps you might require that all elements are present, for consistency, even if they are empty or unused.

My coding style for NixOS modules is:

- *you should permit omitting the module arguments*

- *you should permit omitting the `imports`, `options`, or `config` attributes*

- *you should **avoid** eliding the `config` attribute*

  In other words, if you do define any options, always nest them underneath the `config` attribute.
{/blurb}

## NixOS modules are not language features

The Nix programming language does not provide any built-in support for NixOS modules.  This sometimes confuses people new to either the Nix programming language or the NixOS module system.

The NixOS module system is a domain-specific language implemented within the Nix programming language.  Specifically, the NixOS module system is (mostly) implemented within the [`lib/modules.nix` file included in Nixpkgs](https://github.com/NixOS/nixpkgs/blob/22.05/lib/modules.nix).  If you ever receive a stack trace related to the NixOS module system you will often see functions from `modules.nix` show up in the stack trace, because they are ordinary functions and not language features.

In fact, a NixOS module in isolation is essentially "inert" from the Nix language's point of view.  For example, if you save the following NixOS module to a file named `example.nix`:

```nix
{ config = {
    services.openssh.enable = true;
  };
}
```

… and you evaluate that, the result will be the same, just without the syntactic sugar:

```bash
$ nix eval --file ./example.nix
{ config = { services = { openssh = { enable = true; }; }; }; }
```

{blurb, class:information}
The Nix programming language provides "syntactic sugar" for compressing nested attributes by chaining them using a dot (`.`).  In other words, this Nix expression:

```nix
{ config = {
    services.openssh.enable = true;
  };
}
```

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

… is just a function.  If we save that to `example.nix` and then evaluate that the interpreter will simply say that the file evaluates to a "lambda" (an anonymous function):

```bash
$ nix eval --file ./example.nix
<LAMBDA>
```

… although we can get a more useful result within the `nix repl` by calling our function on a sample argument:

```bash
$ nix repl
…
nix-repl> example = import ./example.nix

nix-repl> input = { config = { services.zookeeper.enable = true; }; }

nix-repl> output = example input

nix-repl> :p output
{ config = { services = { apache-kafka = { enable = true; }; }; }; }

nix-repl> output.config.services.apache-kafka.enable
true
```

This illustrates that our NixOS module really is just a function whose input is an attribute set and whose output is also an attribute set.  There is nothing special about this function other than it happens to be the same shape as what the NixOS module system accepts.

{id: nixos}
## NixOS

So if NixOS modules are just pure functions or pure attribute sets, what turns those functions or attribute sets into a useful operating system?  In other words, what puts the "NixOS" in the "NixOS module system"?

The answer is that this actually happens in two steps:

- *All NixOS modules your system depends on are combined into a single, composite
  attribute set*

  In other words all of the `imports`, `options` declarations, and `config` settings are fully resolved, resulting in one giant attribute set.  The code for combining these modules lives in [`lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/22.05/lib/modules.nix) in Nixpkgs.


- *The final composite attribute set contains a special attribute that builds
  the system*

  Specifically, there will be a `config.system.build.toplevel` attribute path which contains a derivation you can use to build a runnable NixOS system.  The top-level code for assembling an operating system lives in [`nixos/modules/system/activation/top-level.nix`](https://github.com/NixOS/nixpkgs/blob/22.05/nixos/modules/system/activation/top-level.nix) in Nixpkgs.


This will probably make more sense if we use the NixOS module system ourselves to create a fake placeholder value that will stand in for a real operating system.

First, we'll create our own `top-level.nix` module that will include a fake `config.system.build.toplevel` attribute path that is a string instead of a derivation for building an operating system:

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

That imports a separate `other.nix` module which we also need to create:

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
…
nix-repl> result = lib.evalModules { modules = [ ./top-level.nix ]; }

nix-repl> :p result.config
{ system = { build = { toplevel = "Fake NixOS - version 22.05"; }; nixos = { release = "22.05"; }; }; }

nix-repl> result.config.system.build.toplevel
"Fake NixOS - version 22.05"
```

In other words, `lib.evalModules` is the magic function that combines all of our NixOS modules into a composite attribute set.

NixOS essentially does the same thing as in the above example, except on a much larger scale.  Also, in a real NixOS system the final `config.system.build.toplevel` attribute path stores a buildable derivation instead of a string.

## Recursion

The NixOS module system lets modules refer to the final composite configuration using the `config` function argument that is passed into every NixOS module.  For example, this is how our `top-level.nix` module was able to refer to the `system.nixos.release` option that was set in the `other.nix` module:

```nix
# This represents the final composite configuration
# |
{ config, lib, ... }:

{ …

  config = {
    system.build.toplevel =
      "Fake NixOS - version ${config.system.nixos.release}";
                            # |
                            # … which we can use within our configuration
  };
}
```

You're not limited to referencing configuration values set in other NixOS modules; you can even reference configuration values set within the same module.  In other words, NixOS modules support [recursion](https://en.wikipedia.org/wiki/Recursion) where modules can refer to themselves.

As a concrete example of recursion, we can safely merge the `other.nix` module into the `top-level.nix` module:

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

… and this would still work, even though this module now refers to its own configuration values.  The Nix interpreter won't go into an infinite loop because the recursion is still well-founded.

We can better understand why this recursion is well-founded by simulating how `lib.evalModules` works by hand.  Conceptually what `lib.evalModules` does is:

- combine all of the input modules

- compute the [fixed point](https://en.wikipedia.org/wiki/Fixed_point_(mathematics)) of this composite module

We'll walk through this by performing the same steps as `lib.evalModules`.  First, to simplify things we'll consolidate the prior example into a single flake that we can evaluate as we go:

```nix
# Save this to `./evalModules/flake.nix`

{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.05";

  outputs = { nixpkgs, ... }:
    let
      other =
        { lib, ... }:
        { # To save space, this example compresses the code a bit
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
$ nix eval './evalModules#config'
{ system = { build = { toplevel = "Fake NixOS - version 22.05"; }; nixos = { release = "22.05"; }; }; }

$ nix eval './evalModules#config.system.build.toplevel'
"Fake NixOS - version 22.05"
```

{blurb, class:warning}
Various `nix` commands (like `nix eval`) take a flake reference as an argument which has the form:

```
${URI}#${ATTRIBUTE_PATH}
```

In the previous example, the `URI` was `./evalModules` (a file path in this case) and the `ATTRIBUTE_PATH` was `config.system.build.toplevel`.

However, if you use `zsh` as your shell with `EXTENDED_GLOB` glob support (i.e. `setopt extended_glob`) then `zsh` interprets `#` as a special character.  This is why all of the examples from this book quote the flake reference as a precaution, but if you're not using `zsh` or its extended globbing support then you can remove the quotes, like this:

```bash
$ nix eval ./evalModules#config.system.build.toplevel
```
{/blurb}

The first thing that `lib.evalModules` does is to merge the `other` module into the `topLevel` module, which we will simulate by hand by performing the same merge ourselves:

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

After that we compute the fixed point of our module by passing the module's output as its own input, the same way that `evalModules` would:

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
This walkthrough grossly oversimplifies what `evalModules` does.  For starters, we've completely ignored how `evalModules` uses the `options` declarations to:

- check that configuration values match their declared types
- replace missing configuration values with their default values

However, this oversimplification is fine for now.
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
# Access the `config.system.nixos.release` attribute path
= "Fake NixOS - version ${"22.05"}"
```

```nix
# Evaluate the string interpolation
= "Fake NixOS - version 22.05"
```

So even though our NixOS module is defined recursively in terms of itself, that recursion is still well-founded and produces an actual result.
