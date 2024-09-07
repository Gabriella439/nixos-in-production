# Containers

The previous chapter on [Integration Testing](#integration-testing) translated the [PostgREST tutorial](https://postgrest.org/en/v12/tutorials/tut0.html) to an equivalent NixOS test, but that translation left out one important detail: the original tutorial asks the user to run Postgres inside of a `docker` container:

> If Docker is not installed, you can get it here. Next, let’s pull and start the database image:
>
> ```bash
> $ sudo docker run --name tutorial -p 5432:5432 \
>                 -e POSTGRES_PASSWORD=mysecretpassword \
>                 -d postgres
> ```
>
> This will run the Docker instance as a daemon and expose port 5432 to the host system so that it looks like an ordinary PostgreSQL server to the rest of the system.

We don't *have* to use Docker to run Postgres; in fact, I'd normally advise against it and recommend using the Postgres NixOS module instead.  However, we can still use this as an illustrative example of how to translate Docker idioms to NixOS.

More generally, in this chapter we're going to cover container management in the context of NixOS and introduce a spectrum of options ranging from more Docker-native to more NixOS-native.

## Docker registry

The most Docker-native approach is to fetch a container from the Docker registry and to illustrate that we're going to begin from the previous chapter's example integration test:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#integration-test'
```

… but this time instead of using the NixOS `postgres` module:

```nix
# server.nix

…

    services.postgresql = {
      enable = true;

      initialScript = ./setup.sql;
    };

…
```

… we're going to replace that code with a NixOS configuration that runs the official `postgres` image obtained from the Docker registry in almost the same way as the tutorial:

```nix
…

    virtualisation.oci-containers = {
      backend = "docker";

      containers = {
        # We really should call this container "postgres" but we're going to
        # call it "tutorial" just for fun to match the original instructions.
        tutorial = {
          image = "postgres:16.2";

          environment.POSTGRES_PASSWORD = "mysecretpassword";

          extraOptions = [ "--network=host" ];
        };
      };
    };

…
```

We've only made a few changes from the tutorial:

- We specify the container tag (`16.2`) explicitly

  By default if we omit the tag we'll get whatever image the `latest` tag points to.  We'd rather specify a versioned tag to improve the reproducibility of the example because the `latest` tag is a moving target that points to the most recent published version of the `postgres` image.


- We use host networking instead of publishing port 5432

  This means that our container won't use an isolated network and will instead reuse the host machine's network for communicating between containers.  This simplifies the example because at the time of this writing there isn't a stock NixOS option for declaratively managing a Docker network.

NixOS provides a `virtualisation.oci-containers` option hierarchy which lets us declaratively define the same options as `docker run` but it also takes care of several supporting details for us, including:

- installing and running the `docker` service for our NixOS machine

  In particular, the `backend = "docker";` option is what specifies to use Docker as the backend for running our container (instead of the default backend, which is Podman).


- creating a Systemd service to start and stop the container

  This Systemd service runs essentially the same `docker run` command from the tutorial when starting up, and also runs the matching `docker stop` command when shutting down.

We also still need to run the setup commands from `setup.sql` after our container starts up, but we no longer have a convenient `services.postgresql.initialScript` option that we can use for this purpose when going the Docker route.  Instead, we're going to create our own "one shot" Systemd service to take care of this setup process for us:

```nix
    …

    systemd.services.setup-postgresql =
      let
        uri = "postgresql://postgres:mysecretpassword@localhost";

      in
        { wantedBy = [ "multi-user.target" ];

          path = [ pkgs.docker ];

          preStart = ''
            until docker exec tutorial pg_isready --dbname ${uri}; do
                sleep 1
            done
          '';

          script = ''
            docker exec --interactive tutorial psql ${uri} < ${./setup.sql}
          '';

          serviceConfig = {
            Type = "oneshot";

            RemainAfterExit = "yes";
          };
        };

    …
```

We can then sequence our Postgrest service after that one by changing it to be after our setup service:

```diff
    systemd.services.postgrest = {
      …

-     after = [ "postgresql.service" ];
+     after = [ "setup-postgresql.service" ];

      …
    };
```

… and if we re-run the test it still passes:

```bash
$ nix flake check
```

The upside of this approach is that it requires the least buy-in to the NixOS ecosystem.  However, there's one major downside: it only works if the system has network access to a Docker registry, which can be a non-starter for a few reasons:

- this complicates the your deployment architecture

  … since now your system needs network access at runtime to some sort of Docker registry (either the public one or a private registry you host).  This can cause problems when deploying to environments with highly restricted or no network access.


- this adds latency to your system startup

  … because you need to download the image the first time you deploy the system (or upgrade the image).  Moreover, if you do any sort of integration testing (like we are) you have to pay that cost every time you run your integration test.

## Podman

You might notice that the NixOS option hierarchy for running Docker containers is called `virtualisation.oci-containers` and not `virtualisation.docker-containers`.  This is because Docker containers are actually OCI containers (short for "Open Container Initiative") and OCI containers can be run by any OCI-compatible backend.

Moreover, NixOS supports two OCI-compatible backends: Docker and Podman.  In fact, you often might prefer to use Podman (the default) instead of Docker for running containers for a few reasons:

- Podman doesn't require a daemon

  Podman is distributed as a `podman` command line tool that encompasses all of the logic needed to run OCI containers.  The `podman` command line tool doesn't need to delegate instructions to a daemon running in the background like Docker does.


- Improved security

  Podman's "daemonless" operation also implies "rootless" operation.  In other words, you don't need root privileges to run an OCI container using Podman.  Docker, on the other hand, requires elevated privileges by default to run containers (unless you run Docker in rootless mode), which is an enormous security risk.  For example, a misconfigured or compromised `Dockerfile` can allow a container to mount the host's root filesystem which in the *best case* corrupts the host's filesystem with the guest container's files and in the worst case enables total compromise of the host by an attacker.

Switching from Docker to Podman is pretty easy: we only need to change the `virtualisation.oci-containers.backend` option from `"docker"` to `"podman"` (or just delete the option, since `"podman"` is the default):

```diff
     virtualisation.oci-containers = {
-      backend = "docker";
+      backend = "podman";
```

… and then change all command-line references from `podman` to `docker`:

```diff
-          path = [ pkgs.docker ];
+          path = [ pkgs.podman ];
 
           preStart = ''
-            until docker exec tutorial pg_isready --dbname ${uri}; do
+            until podman exec tutorial pg_isready --dbname ${uri}; do
                 sleep 1
             done
           '';
 
           script = ''
-            docker exec --interactive tutorial psql ${uri} < ${./setup.sql}
+            podman exec --interactive tutorial psql ${uri} < ${./setup.sql}
           '';
```

This works because the `podman` command-line tool provides the exact same interface as the the `docker` command-line tool, so it's a drop-in replacement.

## `streamLayeredImage`

If you're willing to lean more into NixOS, there are even better options at your disposal.  For example, you can build the Docker image using NixOS, too!  In fact, Docker images built with NixOS tend to be leaner than official Docker images for two main reasons:

- Nix-built Docker images automatically prune build-time dependencies

  This is actually a feature of the Nix language itself, which autodetects which dependencies are runtime dependencies and only includes those in built packages (including Nix-built Docker images).  Docker images built using traditional `Dockerfile`s usually have to do a bunch of gymnastics to avoid accidentally pulling in build-time dependencies into the image or any of its layers but in Nix you get this feature for free.


- Nix-built Docker images have more cache-friendly layers

  For more details you can read [this post](https://grahamc.com/blog/nix-and-layered-docker-images/) but to summarize: Nix's utilities for building Docker images are smarter than `Dockerfile`s and result in superior layer caching.  This means that as you amend the Docker image to add or remove dependencies you get fewer rebuilds and better disk utilization.

Nixpkgs provides [several utilities for building Docker images](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools) using Nix, but we're only going to concern ourselves with one of those utilities: [`pkgs.dockerTools.streamLayeredImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-streamLayeredImage).  This is the most efficient utility at our disposal that will ensure the best caching and least disk churn out of all the available options.

We'll delete the old `postgrest` service and instead use this `streamLayeredImage` utility to build an application container wrapping `postgrest`.  We can then reference that container in `virtualisation.oci-containers.containers`, like this:

```nix
    …

    virtualisation.oci-containers = {
      backend = "docker";

      containers = {
        …

        postgrest = {
          image = "postgrest:nix";

          imageStream = pkgs.dockerTools.streamLayeredImage {
            name = "postgrest";

            tag = "nix";

            contents = [ pkgs.postgrest ];

            config.Cmd = [ "postgrest" ./tutorial.conf ];
          };

          extraOptions = [ "--network=host" ];
        };
      };
    };

    …
```

You can also clone an example containing all changes up to this point by running:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#docker'
```

This creates a new `postgrest` container that doesn't depend on the Docker registry at all.  Note that the Docker registry *does host* an official `postgrest` image but we're not going to use that image.  Instead, we're using a `postgrest` Docker image built entirely using Nix.

Moreover, this Nix-built docker image integrates efficiently with Nix.  If we add or remove dependencies from our Docker image then we'll only build and store what changed (the "diff"), instead of building and storing an entirely new copy of the whole Docker image archive.

Of course, your next thought might be: "if we're using Nix/NixOS to build and consume Docker images, then do we still need Docker?".  Can we cut out Docker as an intermediate and still preserve most of the same benefits of containerization?

Yes!

## NixOS containers

NixOS actually supports a more NixOS-native alternative to Docker, known as [NixOS containers](https://nixos.org/manual/nixos/stable/#ch-containers).  Under the hood, these use `systemd-nspawn` as the container engine but that's essentially invisible to the end user (you).  The user interface for NixOS containers is much simpler than the Docker-based alternatives, so if you don't need Docker specifically but you still want some basic isolation guarantees then this is the way to go.

The easiest way to illustrate how NixOS containers work is to redo our `postgrest` example to put both Postgres and PostgREST in separate NixOS containers.  We're going to begin by resetting our example back to the non-container example from the previous chapter:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#integration-test'
```

… and then we'll make two changes.  First, instead of running Postgres on the host machine like this:

```nix
    …

    services.postgresql = {
      enable = true;

      initialScript = ./setup.sql;
    };

    …
```

… we're going to change that code to run it inside of a NixOS container (still named `tutorial`) like this:

```nix
    …

    containers.tutorial = {
      autoStart = true;

      config = {
        services.postgresql = {
          enable = true;

          initialScript = ./setup.sql;
        };
      };
    };

    …
```

This change illustrates what's neat about NixOS containers: we can configure them using the same NixOS options that we use to configure the host machine.  All we have to do is wrap the options inside `containers.${NAME}.config` but otherwise we configure NixOS options the same way whether inside or outside of the container.  This is why it's worth trying out NixOS containers if you don't need any Docker-specific functionality but you still want some basic isolation in place.  NixOS containers are significantly more ergonomic to use.

We can also wrap our PostgREST service in the exact same way, replacing this:

```nix
    systemd.services.postgrest = {
      wantedBy = [ "multi-user.target" ];

      after = [ "postgresql.service" ];

      path = [ pkgs.postgrest ];

      script = "postgrest ${./tutorial.conf}";

      serviceConfig.User = "authenticator";
    };

    users = {
      groups.database = { };

      users.authenticator = {
        isSystemUser = true;

        group = "database";
      };
    };
```

… with this:

```nix
    containers.postgrest = {
      autoStart = true;

      config = {
        systemd.services.postgrest = {
          wantedBy = [ "multi-user.target" ];

          after = [ "postgresql.service" ];

          path = [ pkgs.postgrest ];

          script = "postgrest ${./tutorial.conf}";

          serviceConfig.User = "authenticator";
        };

        users = {
          groups.database = { };

          users.authenticator = {
            isSystemUser = true;

            group = "database";
          };
        };
      };
    };
```

… and that's it!  In both cases, we just took our existing NixOS configuration options and wrapped them in something like:

```
    containers."${name}" = {
      autoStart = true;

      config = {
        …
      };
    };
```

… and we got containerization for free.

{blurb, class:information}
Just like the Docker example, these NixOS containers use the host network to connect to one another, meaning that they don't set `privateNetwork = true;` (which creates a private network for the given NixOS container).  At the time of this writing there isn't an easy way to network NixOS containers isolated in this way that doesn't involve carefully selecting a bunch of magic strings (IP addresses and network interfaces).  This is a poor user experience and not one that I feel comfortable documenting or endorsing at the time of this writing.
{/blurb}
