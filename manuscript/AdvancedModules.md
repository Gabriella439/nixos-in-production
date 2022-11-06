# Intermediate module system tricks

The NixOS module system is actually much more sophisticated than the previous chapter let on.  However, at the time of this writing there is little documentation introducing intermediate module system features and this chapter will fill in that gap.

Make sure that you followed the instructions from the "Setting up your development environment" chapter if you would like to test the examples in this chapter.

## `lib` utilities

Nixpkgs provides several utility functions for NixOS modules that are stored underneath the "`lib`" hierarchy, and you can find the source code for those functions in [`lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/22.05/lib/modules.nix).

{blurb, class: information}
If you want to become a NixOS module system expert, take the time to read and understand all of the code in `lib/modules.nix`.

Remember that the NixOS module system is implemented as a domain-specific language in Nix and `lib/modules.nix` contains the complete implementation of that domain-specific language, so if you understand everything in that file then you understand literally everything that there is to know about how the NixOS module system works under the hood.

That said, this chapter will still try to explain things enough so that you don't have to read through that code.
{/blurb}

You do not need to use or understand all of the functions in there, but you do
need to familiarize yourself with the following five primitive functions:

* `lib.mkMerge`
* `lib.mkOverride`
* `lib.mkOrder`
* `lib.mkIf`
* `lib.mkAssert`

By "primitive", I mean that these functions cannot be implemented in terms of other functions.  They all trigger special behavior built into `lib.evalModules`.

We'll cover each one of those functions as well as useful derived functions.

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
{ lib, ... }:

{ config = {
    services.openssh.enable = true;
    users.users.root.initialPassword = "";
  };
}
```

By itself, this is not a very useful thing to do and `mkMerge` is more useful in conjunction with other primitives (especially `mkIf`), but the reason we're starting with `mkMerge` is because everything else is easier to explain once we understand `mkMerge`.

### Merging options

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

… and list-like options, if you specify them twice the lists are combined.  In the above example, it's as if we had instead written this:

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

### Conflicts

Duplicate options cannot necessarily always be merged.  For example, if you merge two configuration sets that disagree on whether to enable a service:

```nix
{ lib, ... }:

{ config = {
    services.openssh.enable = lib.mkMerge [ true false ];

    users.users.root.initialPassword = "";
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

This is because `services.openssh.enable` is defined to be a boolean value, and you can only merge multiple boolean values if all occurrences agree.  You can verify this yourself by changing both occurrences to `true`, which will fix the error.

As a general rule of thumb:

- Most scalar option types will fail to merge distinct values

  e.g. boolean values, strings, integers.


- Most complex option types will successfully merge in the obvious way

  e.g. lists will be concatenated and attribute sets will be unioned.

The most common exception to this rule of thumb is the "lines" type (`lib.types.lines`), which is a string option type that you can set multiple times:

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

… and merging concatenates lines with an intervening newline character:

```bash
$ nix eval .#machine.config.services.zookeeper.extraConf
"initLimit=5\nsyncLimit=2"
```

### `lib.mkOverride`

The `lib.mkOverride` specifies the "priority" of a configuration setting, which comes in handy if you want to override a configuration value that another NixOS module already set.

This most commonly comes up when we need to override an option that was already set by one of our dependencies (typically a NixOS module provided by Nixpkgs).  One example would be overriding the restart frequency of `nginx`:

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

The problem is that when we enable `nginx` that automatically sets a whole bunch of other NixOS options, [including `systemd.services.nginx.serviceConfig.RestartSec`](https://github.com/NixOS/nixpkgs/blob/nixos-22.05/nixos/modules/services/web-servers/nginx/default.nix#L890).  This option is a scalar string option that disallows multiple distinct values because the NixOS module system by default has no way to known which one to pick to resolve the conflict.

However, we can use `mkOverride` to annotate our value with a higher priority so that it overrides the other conflicting definition:

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = lib.mkOverride 50 "5s";
  };
}
```

… and now that works, since we specified a new priority of 50 which is a higher priority than the default priority.  There is also a pre-existing utility named `lib.mkForce` which sets the priority to 50, so we can use that instead:

```nix
{ lib, ... }:

{ config = {
    services.nginx.enable = true;

    systemd.services.nginx.serviceConfig.RestartSec = lib.mkForce "5s";
  };
}
```

{blurb, class:warning}
We do **not** want to do this:

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

The default priority is 100 and **lower** numeric values actually represent **higher** priority.  In other words, a NixOS configuration setting with a priority of 50 takes precedence over a NixOS configuration setting with a priority of 100.

Yes, the NixOS module system confusingly uses lower numbers to indicate higher priorities, but in practice nobody uses explicit numeric priorities.  Instead, people use derived utilities like `lib.mkForce` or `lib.mkDefault` which select the appropriate numeric priority for you.

In extreme cases you might still need to specify an explicit numeric priority.  The most common example is when one of your dependencies already set an option using `lib.mkForce` and you need to override *that*.  In that scenario you could use `lib.mkOverride 49`, which would take precedence over `lib.mkForce`

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

However, leaning on higher-and-higher priorities is usually an anti-pattern and it's usually better to fix the upstream code if you can.  We'll revisit this dilemma in a later chapter when we talk in more depth about NixOS module design.

## `lib.mkIf`

`mkIf` is far-and-away the most widely used NixOS module primitive, because you can use `mkIf` to selectively enable certain configuration settings based on the value of another configuration setting.

An extremely common idiom from Nixpkgs is to use `mkIf` in conjunction with an `enable` option, like this:

```nix
# cowsay.nix

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
```

… with the intention that a downstream module would use the upstream module like this:

```nix
# module.nix

{ imports = [ ./cowsay.nix ];

  config = {
    services.cowsay.enable = true;

    users.users.root.initialPassword = "";
  };
}
```

Save the above two modules to `cowsay.nix` and `module.nix` respectively, then start the virtual machine and log in as `root`.  You should be able to check on the status of the `cowsay` service like this:

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

The first (and most important reason) why this doesn't work is because it triggers an infinite loop:

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

… and the reason why `lib.mkIf` doesn't have this problem is because `evalModules` pushes `mkIf` conditions to the "leaves" of the configuration tree, as if we had instead written this:

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

The second reason we use `lib.mkIf` is because it correctly handles the fallback case.  To see why that matters, consider this example that tries to create a `service.kafka.enable` short-hand synonym for `services.apache-kafka.enable`::

```nix
# ./just-kafka.nix

{ config, lib, ... }:

{ options.services.kafka.enable = lib.mkEnableOption "apache";

  config.services.apache-kafka.enable = config.services.kafka.enable;
}
```

However, if a downstream module were to set `services.apache-kafka.enable`:

```nix
{ imports = [ ./just-kafka.nix ];

  config.services.apache-kafka.enable = true;
}
```

… then that would conflict because `just-kafka.nix` is explicitly setting `services.kafka.enable` to `false` by default (at priority 100), and our own module is setting `services.apache-kafka.enable` to `true` (also at priority 100).

Had we instead used `mkIf` like this:

```nix
# ./just-kafka.nix

{ config, lib, ... }:

{ options.services.kafka.enable = lib.mkEnableOption "apache";

  config.services.apache-kafka.enable =
    lib.mkIf config.services.kafka.enable true;
}
```

… then that would do the right thing because in the default case `services.apache-kafka.enable` would be unset, which would be the same thing as being set to `false` at priority 1500.

#### TODO

- Explain that you want to import modules by path, not value
- Explain the `cfg` idiom
- Talk about merging option values
- Talk about common pitfalls (especially related to `mkForce`)
- Talk about `lib.mkDefault` trick and not creating an option default that
  doesn't depend on another option's value
- Exercise: Query another option/config value from command line or nix repl
- Exercise: Why can't you set the same option twice without `mkMerge`?
