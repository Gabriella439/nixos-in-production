# A deep dive into the module system

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
- you should *not* permit eliding the `config` attributes

  In other words, if you do set any options, always nest them underneath the `config` attribute.
{/blurb}
