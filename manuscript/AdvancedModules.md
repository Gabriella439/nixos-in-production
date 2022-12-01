# Advanced option definitions

NixOS option definitions are actually much more sophisticated than the previous chapter let on and in this chapter we'll cover some common tricks and pitfalls.

Make sure that you followed the instructions from the "Setting up your development environment" chapter if you would like to test the examples in this chapter.

## Imports

The NixOS module system lets you import other modules by their path, which merges their option declarations and option definitions with the current module.  But, did you know that the elements of an `imports` list don't have to be paths?

You can put inline NixOS configurations in the `imports` list, like these:

```nix
{ imports = [
    { services.openssh.enable = true; }

    { users.users.root.initialPassword = ""; }
  ];
}
```

… and they will behave as if you had imported files with the same contents as those inline configurations.

In fact, anything that is a valid NixOS module can go in the import list, including NixOS modules that are functions:

```nix
{ imports = [
    { services.openssh.enable = true; }

    ({ lib, ... }: { users.users.root.initialPassword = lib.mkDefault ""; })
  ];
}
```

I will make use of this trick in a few examples below, so that we can simulate modules importing other modules within a single file.

## `lib` utilities

Nixpkgs provides several utility functions for NixOS modules that are stored underneath the "`lib`" hierarchy, and you can find the source code for those functions in [`lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/22.05/lib/modules.nix).

{blurb, class: information}
If you want to become a NixOS module system expert, take the time to read and understand all of the code in `lib/modules.nix`.

Remember that the NixOS module system is implemented as a domain-specific language in Nix and `lib/modules.nix` contains the implementation of that domain-specific language, so if you understand everything in that file then you understand essentially all that there is to know about how the NixOS module system works under the hood.

That said, this chapter will still try to explain things enough so that you don't have to read through that code.
{/blurb}

You do not need to use or understand all of the functions in `lib/modules.nix`, but you do need to familiarize yourself with the following four primitive functions:

- `lib.mkMerge`
- `lib.mkOverride`
- `lib.mkIf`
- `lib.mkOrder`

By "primitive", I mean that these functions cannot be implemented in terms of other functions.  They all hook into special behavior built into `lib.evalModules`.

### `mkMerge`

The `lib.mkMerge` function merges a list of "configuration sets" into a single "configuration set" (where "configuration set" means a potentially nested attribute set of configuration option settings).

For example, the following NixOS module:

```nix
{ lib, ... }:

{ config = lib.mkMerge [
    { services.openssh.enable = true; }
    { users.users.root.initialPassword = ""; }
  ];
}
```

… is equivalent to this NixOS module:

```nix
{ config = {
    services.openssh.enable = true;
    users.users.root.initialPassword = "";
  };
}
```

{blurb, class: information}
You might wonder whether you should merge modules using `lib.mkMerge` or merge them using the `imports` list.  After all, we could have also written the previous `mkMerge` example as:

```nix
{ imports = [
    { services.openssh.enable = true; }
    { users.users.root.initialPassword = ""; }
  ];
}
```

… and that would have produced the same result.  So which is better?

The short answer is: `lib.mkMerge` is usually what you want.

The long answer is that the main trade-off between `imports` and `lib.mkMerge` is:

- *The `imports` section can merge NixOS modules that are functions*

  `lib.mkMerge` can only merge configuration sets and not functions.


- *The list of `imports` can't depend on any configuration values*

  In practice, this means that you can easily trigger an infinite recursion if you try to do anything fancy using `imports` and you can typically fix the infinite recursion by switching to `lib.mkMerge`.

The latter point is why you should typically prefer using `lib.mkMerge`.
{/blurb}

#### Merging options

You can merge configuration sets that define same option multiple times, like this:

```nix
{ lib, ... }:

{ config = lib.mkMerge [
    { networking.firewall.allowedTCPPorts = [ 80 ]; }
    { networking.firewall.allowedTCPPorts = [ 443 ]; }
    { users.users.root.initialPassword = ""; }
  ];
}
```

… and the outcome of merging two identical attribute paths depends on the option's "type".

For example, the `networking.firewall.allowedTCPPorts` option's type is:

```bash
$ nix eval .#machine.options.networking.firewall.allowedTCPPorts.type.description
"list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)"
```

If you specify a list-valued option twice, the lists are combined, so the above example reduces to this:

```nix
{ lib, ... }:

{ config = lib.mkMerge [
    networking.firewall.allowedTCPPorts = [ 80 443 ]; }
    users.users.root.initialPassword = "";
  ];
}
```

… and we can even prove that by querying the final value of the option from the command line:

```bash
$ nix eval .#machine.config.networking.firewall.allowedTCPPorts
[ 80 443 ]
```

However, you might find the `nix repl` more convenient if you prefer to interactively browse the available options.  Run this command:

```bash
$ nix repl .#machine
…
Added 7 variables.
```

… which will load your NixOS system into the REPL and now you can use tab-completion to explore what is available:

```bash
nix-repl> config.<TAB>
config.appstream          config.nix
config.assertions         config.nixops
…
nix-repl> config.networking.<TAB>
config.networking.bonds
config.networking.bridges
…
nix-repl> config.networking.firewall.<TAB>
config.networking.firewall.allowPing
config.networking.firewall.allowedTCPPortRanges
…
nix-repl> config.networking.firewall.allowedTCPPorts
[ 80 443 ]
```

> **Exercise**: Try to save the following NixOS module to `module.nix`, which specifies the same option twice without using `lib.mkMerge`:
>
> ```nix
> { lib, ... }:
>
> { config = {
>     networking.firewall.allowedTCPPorts = [ 80 ];
>     networking.firewall.allowedTCPPorts = [ 443 ];
>     users.users.root.initialPassword = "";
>   };
> }
> ```
>
> This will fail to deploy.  Do you understand why?  Specifically, is the failure a limitation of the NixOS module system or the Nix programming language?

You can also nest `lib.mkMerge` underneath an attribute.  For example, this:

```nix
{ config = lib.mkMerge [
    { networking.firewall.allowedTCPPorts = [ 80 ]; }
    { networking.firewall.allowedTCPPorts = [ 443 ]; } 
  ];
}
```

… is the same as this:

```nix
{ config.networking = lib.mkMerge [
    { firewall.allowedTCPPorts = [ 80 ]; }
    { firewall.allowedTCPPorts = [ 443 ]; } 
  ];
}
```

… is the same as this:

```nix
{ config.networking.firewall = lib.mkMerge [
    { allowedTCPPorts = [ 80 ]; }
    { allowedTCPPorts = [ 443 ]; } 
  ];
}
```

… is the same as this:

```nix
{ config.networking.firewall.allowedTCPPorts = lib.mkMerge [ [ 80 ] [ 443 ] ];
}
```

… is the same as this:

```nix
{ config.networking.firewall.allowedTCPPorts = [ 80 443 ]; }
```

#### Conflicts

Duplicate options cannot necessarily always be merged.  For example, if you merge two configuration sets that disagree on whether to enable a service:

```nix
{ lib, ... }:

{ config = {
    services.openssh.enable = lib.mkMerge [ true false ];
  };
}
```

… then that will fail at evaluation time with this error:

```
error: The option `services.openssh.enable' has conflicting definition values:
       - In `/nix/store/…-source/module.nix': true
       - In `/nix/store/…-source/module.nix': false
(use '--show-trace' to show detailed location information)
```

This is because `services.openssh.enable` is declared to have a boolean type, and you can only merge multiple boolean values if all occurrences agree.  You can verify this yourself by changing both occurrences to `true`, which will fix the error.

As a general rule of thumb:

- *Most scalar option types will fail to merge distinct values*

  e.g. boolean values, strings, integers.


- *Most complex option types will successfully merge in the obvious way*

  e.g. lists will be concatenated and attribute sets will be combined.

The most common exception to this rule of thumb is the "lines" type (`lib.types.lines`), which is a string option type that you can define multiple times.  `services.zookeeper.extraConf` is an example of one such option that has this type:

```nix
{ lib, ... }:

{ config = {
    services.zookeeper = {
      enable = true;

      extraConf = lib.mkMerge [ "initLimit=5" "syncLimit=2" ];
    };
  };
}
```

… and merging multiple occurrences of that option concatenates them as lines by inserting an intervening newline character:

```bash
$ nix eval .#machine.config.services.zookeeper.extraConf
"initLimit=5\nsyncLimit=2"
```

### `mkOverride`

The `lib.mkOverride` function specifies the "priority" of an option definition, which comes in handy if you want to override a configuration value that another NixOS module already defined.

#### Higher priority overrides

This most commonly comes up when we need to override an option that was already defined by one of our dependencies (typically a NixOS module provided by Nixpkgs).  One example would be overriding the restart frequency of `nginx`:

```nix
{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = "5s";
  };
}
```

The above naïve attempt will fail at evaluation time with:

```nix
error: The option `systemd.services.nginx.serviceConfig.RestartSec' has conflicting definition values:
       - In `/nix/store/…-source/nixos/modules/services/web-servers/nginx/default.nix': "10s"
       - In `/nix/store/…-source/module.nix': "5s"
(use '--show-trace' to show detailed location information)
```

The problem is that when we enable `nginx` that automatically defines a whole bunch of other NixOS options, [including `systemd.services.nginx.serviceConfig.RestartSec`](https://github.com/NixOS/nixpkgs/blob/nixos-22.05/nixos/modules/services/web-servers/nginx/default.nix#L890).  This option is a scalar string option that disallows multiple distinct values because the NixOS module system by default has no way to known which one to pick to resolve the conflict.

However, we can use `mkOverride` to annotate our value with a higher priority so that it overrides the other conflicting definition:

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = lib.mkOverride 50 "5s";
  };
}
```

… and now that works, since we specified a new priority of `50` takes priority over the default priority of `100`.  There is also a pre-existing utility named `lib.mkForce` which sets the priority to 50, so we could have also used that instead:

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = lib.mkForce "5s";
  };
}
```

{blurb, class:warning}
You do **not** want to do this:

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig = lib.mkForce { RestartSec = "5s" };
  };
}
```

That is not equivalent, because it overrides not only the `RestartSec` attribute, but also all other attributes underneath the `serviceConfig` attribute (like `Restart`, `User`, and `Group`, all of which are now gone).

You always want to narrow your use of `lib.mkForce` as much as possible to protect against this common mistake.
{/blurb}

The default priority is `100` and **lower** numeric values actually represent **higher** priority.  In other words, an option definition with a priority of `50` takes precedence over an option definition with a priority of `100`.

Yes, the NixOS module system confusingly uses lower numbers to indicate higher priorities, but in practice you will rarely see explicit numeric priorities.  Instead, people tend to use derived utilities like `lib.mkForce` or `lib.mkDefault` which select the appropriate numeric priority for you.

In extreme cases you might still need to specify an explicit numeric priority.  The most common example is when one of your dependencies already define an option using `lib.mkForce` and you need to override *that*.  In that scenario you could use `lib.mkOverride 49`, which would take precedence over `lib.mkForce`

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = lib.mkMerge [
       (lib.mkForce "5s")
       (lib.mkOverride 49 "3s")
    ];
  };
}
```

… which will produce a final value of:

```BashSession
$ nix eval .#machine.config.systemd.services.nginx.serviceConfig.RestartSec
"3s"
```

#### Lower priority overrides

The default values for options also have a priority, which is priority `1500` and there's a `lib.mkOptionDefault` that sets a configuration value to that same priority.

That means that a NixOS module like this:

```nix
{ lib, ... }:

{ options.foo = lib.mkOption {
    default = 1;
  };
}
```

… is the exact same thing as a NixOS module like this:

```nix
{ lib, ... }:

{ options.foo = lib.mkOption { };

  config.foo = lib.mkOptionDefault 1;
}
```

However, you will more commonly use `lib.mkDefault` which defines a configuration option with priority `1000`.  Typically you'll use `lib.mkDefault` if you want to override the default value of an option, while still allowing a downstream user to override the option yet again at the normal priority (`100`).

### `mkIf`

`mkIf` is far-and-away the most widely used NixOS module primitive, because you can use `mkIf` to selectively enable certain options based on the value of another option.

An extremely common idiom from Nixpkgs is to use `mkIf` in conjunction with an `enable` option, like this:

```nix
# module.nix

let
  # Pretend that this came from another file
  cowsay =
    { config, lib, pkgs, ... }:

    { options.services.cowsay = {
        enable = lib.mkEnableOption "cowsay";

        greeting = lib.mkOption {
          description = "The phrase the cow will greet you with";

          type = lib.types.str;

          default = "Hello, world!";
        };
      };

      config = lib.mkIf config.services.cowsay.enable {
        systemd.services.cowsay = {
          wantedBy = [ "multi-user.target" ];

          script = "${pkgs.cowsay}/bin/cowsay ${config.services.cowsay.greeting}";
        };
      };
    }

in
  { imports = [ cowsay ];

    config = {
      services.cowsay.enable = true;

      users.users.root.initialPassword = "";
    };
  }
```

If you launch the above NixOS configuration and log in as `root` you should be
able to verify that the `cowsay` service is running like this:

```
[root@nixos:~]# systemctl status cowsay
○ cowsay.service
     Loaded: loaded (/etc/systemd/system/cowsay.service; enabled; preset: enabl>
     Active: inactive (dead) since Sat 2022-11-05 20:11:05 UTC; 43s ago
   Duration: 106ms
    Process: 683 ExecStart=/nix/store/v02wsh00gi1vcblpcl8p103qhlpkaifb-unit-scr>
   Main PID: 683 (code=exited, status=0/SUCCESS)
         IP: 0B in, 0B out
        CPU: 19ms

Nov 05 20:11:04 nixos systemd[1]: Started cowsay.service.
Nov 05 20:11:05 nixos cowsay-start[689]:  _______________
Nov 05 20:11:05 nixos cowsay-start[689]: < Hello, world! >
Nov 05 20:11:05 nixos cowsay-start[689]:  ---------------
Nov 05 20:11:05 nixos cowsay-start[689]:         \   ^__^
Nov 05 20:11:05 nixos cowsay-start[689]:          \  (oo)\_______
Nov 05 20:11:05 nixos cowsay-start[689]:             (__)\       )\/\
Nov 05 20:11:05 nixos cowsay-start[689]:                 ||----w |
Nov 05 20:11:05 nixos cowsay-start[689]:                 ||     ||
Nov 05 20:11:05 nixos systemd[1]: cowsay.service: Deactivated successfully.
```

You might wonder why we need a `mkIf` primitive at all.  Couldn't we use an `if` expression like this instead?

```nix
{ config, lib, pkgs, ... }:

{ …

  config = if config.services.cowsay.enable then {
    systemd.services.cowsay = {
      wantedBy = [ "multi-user.target" ];

      script = "${pkgs.cowsay}/bin/cowsay ${config.services.cowsay.greeting}";
    };
  } else { };
}
```

The most important reason why this doesn't work is because it triggers an infinite loop:

```
error: infinite recursion encountered

       at /nix/store/vgicc88fhmlh7mwik7gqzzm2jyfva9l9-source/lib/modules.nix:259:21:

          258|           (regularModules ++ [ internalModule ])
          259|           ({ inherit lib options config specialArgs; } // specialArgs);
             |                     ^
          260|         in mergeModules prefix (reverseList collected);
(use '--show-trace' to show detailed location information)
```

The reason why is because the recursion is not well-founded:

```nix
# This attribute directly depends on itself
# ↓           ↓
  config = if config.services.cowsay.enable then {
```

… and the reason why `lib.mkIf` doesn't share the same problem is because `evalModules` pushes `mkIf` conditions to the "leaves" of the configuration tree, as if we had instead written this:

```nix
{ config, lib, pkgs, ... }:

{ …

  config = {
    systemd.services.cowsay = {
      wantedBy = lib.mkIf config.services.cowsay.enable [ "multi-user.target" ];

      script =
        lib.mkIf config.services.cowsay.enable
          "${pkgs.cowsay}/bin/cowsay ${config.services.cowsay.greeting}";
    };
  };
}
```

… which makes the recursion well-founded.

The second reason we use `lib.mkIf` is because it correctly handles the fallback case.  To see why that matters, consider this example that tries to create a `service.kafka.enable` short-hand synonym for `services.apache-kafka.enable`:

```nix
let
  kafkaSynonym =
    { config, lib, ... }:

    { options.services.kafka.enable = lib.mkEnableOption "apache";

      config.services.apache-kafka.enable = config.services.kafka.enable;
    };

in
  { imports = [ kafkaSynonym ];

    config.services.apache-kafka.enable = true;
  }
```

The above example leads to a conflict because the `kafkaSynonym` module defines `services.kafka.enable` to `false` (at priority 100), and the downstream module defines `services.apache-kafka.enable` to `true` (also at priority 100).

Had we instead used `mkIf` like this:

```nix
let
  kafkaSynonym =
    { config, lib, ... }:

    { options.services.kafka.enable = lib.mkEnableOption "apache";

      config.services.apache-kafka.enable =
        lib.mkIf config.services.kafka.enable true;
    };

in
  { imports = [ kafkaSynonym ];

    config.services.apache-kafka.enable = true;
  }
```

… then that would do the right thing because in the default case `services.apache-kafka.enable` would remain undefined, which would be the same thing as being defined as `false` at priority `1500`.  That avoids defining the same option twice at the same priority.

### `mkOrder`

The NixOS module system strives to make the behavior of our system depend as little as possible on the order in which we import or `mkMerge` NixOS modules.  In other words, if we import two modules that we depend on:

```nix
{ imports = [ ./A.nix ./B.nix ]; }
```

… then ideally the behavior shouldn't change if we import those same two modules in a different order:

```nix
{ imports = [ ./B.nix ./A.nix ]; }
```

… and in *most cases* that is true.  99% of the time you can safely sort your import list and either your NixOS system will be *exactly* the same as before (down to the hash) or *essentially* the same as before, meaning that the difference is irrelevant.  However, for those 1% of cases where order matters we need the `lib.mkOrder` function.

Here's one example of where ordering matters:

```nix
let
  moduleA = { pkgs, ... }: {
    environment.defaultPackages = [ pkgs.gcc ];
  };

  moduleB = { pkgs, ... }: {
    environment.defaultPackages = [ pkgs.clang ];
  };

in
  { imports = [ moduleA moduleB ];

    users.users.root.initialPassword = "";
  }
```

Both the `gcc` package and `clang` package add a `cc` executable to the `PATH`, so the order matters here because the first `cc` on the `PATH` wins.

Surprisingly, `clang`'s `cc` is the first one on the `PATH`, even though we imported `moduleB` second:

```bash
[root@nixos:~]# readlink $(type -p cc)
/nix/store/6szy6myf8vqrmp8mcg8ps7s782kygy5g-clang-wrapper-11.1.0/bin/cc
```

… and if we flip the order imports:

```nix
    imports = [ moduleB moduleA ];
```

… then `gcc`'s `cc` comes first on the `PATH`:

```bash
[root@nixos:~]# readlink $(type -p cc)
/nix/store/9wqn04biky07333wkl35bfjv9zv009pl-gcc-wrapper-9.5.0/bin/cc
```

This sort of order-sensitivity frequently arises for "list-like" option types, including actual lists or string types like `lines` that concatenate multiple definitions.

Fortunately, we can fix situations like these with the `lib.mkOrder` function, which specifies a numeric ordering that NixOS will respect when merging multiple definitions of the same option.

Every option's numeric order is `1000` by default, so if we set the numeric order of `clang` to `1001`:

```nix
let
  moduleA = { pkgs, ... }: {
    environment.defaultPackages = [ pkgs.gcc ];
  };

  moduleB = { lib, pkgs, ... }: {
    environment.defaultPackages = lib.mkOrder 1001 [ pkgs.clang ];
  };

in
  { imports = [ moduleA moduleB ];

    users.users.root.initialPassword = "";
  }
```

… then `gcc` will always come first on the `PATH`, no matter which order we import the modules.

You can also use `lib.mkBefore` and `lib.mkAfter`, which provide convenient synonyms for numeric order `500` and `1500`, respectively:

```nix
mkBefore = mkOrder 500;

mkAfter = mkOrder 1500;
```

… so we could have also written:

```nix
let
  moduleA = { pkgs, ... }: {
    environment.defaultPackages = [ pkgs.gcc ];
  };

  moduleB = { lib, pkgs, ... }: {
    environment.defaultPackages = lib.mkAfter [ pkgs.clang ];
  };

in
  { imports = [ moduleA moduleB ];

    users.users.root.initialPassword = "";
  }
```
