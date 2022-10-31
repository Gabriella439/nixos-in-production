# Our first web server

Now that we can build and run a local NixOS machine we can create our first toy web server.  We will use this toy server throughout this book as the running example which will start off simple and slowly grow in maturity as we increase the realism of the example and build out the supporting infrastructure.

## Hello, world!

Let's build on the baseline `module.nix` by creating a machine that serves a simple static "Hello, world!" page on `http://localhost`:

```nix
{ pkgs, ... }:

{ networking.firewall.allowedTCPPorts = [ 80 ];

  services.nginx = {
    enable = true;

    virtualHosts.localhost = {
      default = true;

      locations."/" = {
        index = "index.html";

        root = pkgs.writeTextDir "index.html" ''
         <html>
         <body>
         Hello, world!
         </body>
         </html>
       '';
      };
    };
  };

  users.users.root.initialPassword = "";
}
```

You can read the above code as saying:

- Enable `nginx` which currently only listens on `localhost`

  In other words, `nginx` will only respond to requests addressed to `localhost` (e.g. `127.0.0.1`).

- Open port 80 on the firewall

  … since that is the port that `nginx` will listen on by default until we create a certificate and enable TLS.

- Serve a static web page

  … which is a very bare-bones "Hello, world!" HTML page.

Following the same instructions as the previous chapter:

- begin from the `flake.nix` file included in the previous chapter

- save the above NixOS configuration to a `module.nix` file

  … in the same directory as the `flake.nix` file.

- Run `nix run`

  … also from within the same directory

You can then log into the server as the `root` user with an empty password:

```bash
nixos login: root<Enter>
Password: <Enter>

[root@nixos:~]# 
```

… and then use `curl` to verify that `nginx` is serving the web page on port 80:

```bash
[root@nixos:~]# curl http://localhost
<html>
<body>
Hello, world!
</body>
</html>
```

{blurb, class: warning}
In general I don't recommend testing things by hand like this.  Later on we'll automate this sort of testing using NixOS's support for integration tests.
{/blurb}

We need to make one additional change before we can open the same page in our
browser.  Stop the NixOS server by:

- Typing `Ctrl`-`a` + `c` to open the `qemu` console:

  … which should look like this:

  ```bash
  [root@nixos:~]# <Ctrl-a><c>
  QEMU 7.1.0 monitor - type 'help' for more information
  (qemu) 
  ```

- Entering the `quit` command in the `qemu` console to stop the virtual machine

  ```bash
  (qemu) quit<Enter>
  ```

Now restart the server, but this time using the following modified run `command`:

```bash
$ QEMU_NET_OPTS='hostfwd=tcp::8080-:80' nix run
```

This instructs `qemu` to forward port 80 on the virtual machine (the "guest") to port 8080 on our development machine (the "host").  Once the above command succeeds you can open the web page in your browser by visiting:

[`http://localhost:8080`](http://localhost:8080)

… which should display the following web page>

> Hello, world!

## DevOps

The above example illustrates how far you can take DevOps with NixOS.  If the web page represents the software development half of the project (the "Dev") and the `nginx` configuration represents the operational half of the project (the "Ops") then we can in principle store both the "Dev" and the "Ops" halves of our project within the same file.  In general, we typically don't want to do this, but we *can* and there's no limit to how far we can blur the boundary between Dev and Ops when we use NixOS.

Just for fun: let's blur the boundary even further by templating the web page with some system configuration options:

```nix
{ config, lib, pkgs, ... }:

{ networking.firewall.allowedTCPPorts = [ 80 ];

  services.nginx = {
    enable = true;

    virtualHosts.localhost = {
      default = true;

      locations."/" = {
        index = "index.html";

        root = pkgs.writeTextDir "index.html" ''
         <html>
         <body>
         This server's firewall has the following open ports:

         <ul>
         ${
         let
           renderPort = port: "<li>${toString port}</li>\n";

          in
            lib.concatMapStrings renderPort config.networking.firewall.allowedTCPPorts
         }
         </ul>
         </body>
         </html>
       '';
      };
    };
  };

  users.users.root.initialPassword = "";
}
```

… which should now display the following web page:

> This server's firewall has the following open ports:
> 
> - 80

{blurb, class: information}
There are less roundabout ways to query our system configuration.  For example, using the same `flake.nix` file we can query the open ports using:

```bash
$ nix eval .#machine.config.networking.firewall.allowedTCPPorts
[ 80 ]
```

I'll cover this in more detail in a later chapter on the NixOS module system.
{/blurb}

## Improving robustness

* * *

```nix
{ pkgs, ... }:

let
  overlay = self: super: {
    website = self.writeTextDir "index.html"
      ''
      <html>
      <body>
      <button id='add'>+</button>
      </body>
      <script>
      let add = document.getElementById('add');

      function newTask() {
          let subtract = document.createElement('button');

          subtract.textContent = "-";

          let input = document.createElement('input');

          input.setAttribute('type', 'text');

          let div = document.createElement('div');

          div.replaceChildren(subtract, input);

          function remove() {
            div.replaceChildren();

            div.remove();
          }

          subtract.addEventListener('click', remove);

          add.before(div);
      }

      add.addEventListener('click', newTask);
      </script>
      </html>
      '';
  };

in
  { networking.firewall.allowedTCPPorts = [ 80 ];

    nixpkgs.overlays = [ overlay ];

    services.nginx = {
      enable = true;

      virtualHosts.localhost = {
        default = true;

        locations."/" = {
          index = "index.html";

          root = pkgs.website;
        };
      };
    };

    users.users.root.initialPassword = "";
  }
```
