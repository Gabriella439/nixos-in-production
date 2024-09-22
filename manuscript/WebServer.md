# Our first web server

Now that we can build and run a local NixOS virtual machine we can create our first toy web server.  We will use this server throughout this book as the running example which will start off simple and slowly grow in maturity as we increase the realism of the example and build out the supporting infrastructure.

{id: hello-world}
## Hello, world!

We'll begin from the template project from "Setting up your development environment".  You can either begin from the previous chapter by running the following command (if you haven't done so already):

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.10#setup'
```

… or if you want to skip straight to the final result at the end of this chapter you can run:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.10#server'
```

Let's modify `module.nix` to specify a machine that serves a simple static "Hello, world!" page on `http://localhost`:

```nix
# module.nix

{ pkgs, ... }:

{ services = {
    getty.autologinUser = "root";

    nginx = {
      enable = true;

      virtualHosts.localhost.locations."/" = {
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

  networking.firewall.allowedTCPPorts = [ 80 ];

  virtualisation.forwardPorts = [
    { from = "host"; guest.port = 80; host.port = 8080; }
  ];

  system.stateVersion = "23.11";
}
```

You can read the above code as saying:

- *Enable `nginx` which currently only listens on `localhost`*

  In other words, `nginx` will only respond to requests addressed to `localhost` (e.g. `127.0.0.1`).


- *Serve a static web page*

  … which is a bare-bones "Hello, world!" HTML page.


- *Open port 80 on the virtual machine's firewall*

  … since that is the port that `nginx` will listen on by default until we create a certificate and enable TLS.


- *Forward port 8080 on the "host" to port 80 on the "guest"*

  The "guest" is the virtual machine and the "host" is your development machine.


- *Allow the `root` user to log in with an empty password*


- *Set the system's "state version" to 23.11*

{blurb, class: information}
You always want to specify a system state version that matches the starting version of Nixpkgs for that machine and *never change it* afterwards.  In other words, even if you upgrade Nixpkgs later on you would keep the state version the same.

Nixpkgs uses the state version to migrate your NixOS system because in order to migrate your system each migration needs to know where your system started from.

Two common mistakes NixOS users sometimes make are:

- *updating the state version when they upgrade Nixpkgs*

  This will cause the machine to never be migrated because Nixpkgs will think that the machine was never deployed to an older version.


- *specifying a uniform state version across a fleet of NixOS machines*

  For example, you might have one NixOS machine in your data center that was first deployed using Nixpkgs 23.05 and another machine in your data center that was first deployed using Nixpkgs 23.11.  If you try to change their state versions to match then one or the other might not upgrade correctly.
{/blurb}

If you deploy that using `nix run` you can open the web page in your browser by visiting [`http://localhost:8080`](http://localhost:8080) which should display the following contents:

> Hello, world!

{blurb, class: warning}
In general I don't recommend testing things by hand like this.  Remember the "master cue":

> Every common build/test/deploy-related activity should be possible with at most a single command using Nix’s command line interface.

In a later chapter we'll cover how to automate this sort of testing using NixOS's support for integration tests.  These tests will also take care of starting up and tearing down the virtual machine for you so that you don't have to do that by hand either.
{/blurb}

## DevOps

The previous example illustrates how NixOS promotes DevOps on a small scale.  If the inline web page represents the software development half of the project (the "Dev") and the `nginx` configuration represents the operational half of the project (the "Ops") then we can in principle store both the "Dev" and the "Ops" halves of our project within the same file.  As an extreme example, we can even template the web page with system configuration options!

```nix
# module.nix

{ config, lib, pkgs, ... }:

{ services = {
    getty.autologinUser = "root";

    nginx = {
      enable = true;

      virtualHosts.localhost.locations."/" = {
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

  networking.firewall.allowedTCPPorts = [ 80 ];

  virtualisation.forwardPorts = [
    { from = "host"; guest.port = 80; host.port = 8080; }
  ];

  system.stateVersion = "23.11";
}
```

If you restart the machine and refresh [http://localhost:8080](http://localhost:8080) the page should now display:

> This server's firewall has the following open ports:
> 
> - 80

{blurb, class: information}
There are less roundabout ways to query our system's configuration that don't involve serving a web page.  For example, using the same `flake.nix` file we can more directly query the open ports using:

```bash
$ nix eval '.#machine.config.networking.firewall.allowedTCPPorts'
[ 80 ]
```
{/blurb}

## TODO list

Now we're going to create the first prototype of a toy web application: a TODO list implemented entirely in client-side JavaScript (later on we'll add a backend service).

Create a subdirectory named `www` within your current directory:

```bash
$ mkdir www
```

… and then save a file named `index.html` with the following contents underneath that subdirectory:

```html
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
```

In other words, the above file should be located at `www/index.html` relative to the directory containing your `module.nix` file.

Now save the following NixOS configuration to `module.nix`:

```nix
# module.nix

{ services = {
    getty.autologinUser = "root";

    nginx = {
      enable = true;

      virtualHosts.localhost.locations."/" = {
        index = "index.html";

        root = ./www;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  virtualisation.forwardPorts = [
    { from = "host"; guest.port = 80; host.port = 8080; }
  ];

  system.stateVersion = "23.11";
}
```

If you restart the virtual machine and refresh the web page you'll see a single `+` button:

{align: left}
![](./plus-button.png)

Each time you click the `+` button it will add a TODO list item consisting of:

- A text entry field to record the TODO item

- A `-` button to delete the TODO item



{align: left}
![](./todo-list.png)

## Passing through the filesystem

The previous NixOS configuration requires rebuilding and restarting the virtual machine every time we change the web page.  If you try to change the `./www/index.html` file while the virtual machine is running you won't see any changes take effect.

However, we can pass through our local filesystem to the virtual machine so that we can easily test changes.  To do so, add the following option to the configuration:

```nix
  virtualisation.sharedDirectories.www = {
    source = "$WWW";
    target = "/var/www";
  };
```

… and change `module.nix` to reference `/var/www`, like this:

```nix
    virtualHosts.localhost.locations."/" = {
      index = "index.html";
      root = "/var/www";
    };
```

Finally, restart the machine, except with a slightly modified version of our original `nix run` command:

```bash
$ WWW="$PWD/www" nix run
```

Now, we only need to refresh the page to view any changes we make to `index.html` and we no longer need to restart the virtual machine.

**Exercise**: Add a "TODO list" heading (i.e. `<h1>TODO list</h1>`)to the web page and refresh the page to confirm that your changes took effect.
