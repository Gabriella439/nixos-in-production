# Containers

The previous chapter on [Integration Testing](#integration-testing) translated the [PostgREST tutorial](https://postgrest.org/en/v12/tutorials/tut0.html) to an equivalent NixOS test, but that translation left out one important detail: the original tutorial asks the user to run Postgres inside of a `docker` container:

> If Docker is not installed, you can get it here. Next, let’s pull and start the database image:
>
> ```bash
> $ sudo docker run --name tutorial -p 5433:5432 \
>                 -e POSTGRES_PASSWORD=mysecretpassword \
>                 -d postgres
> ```
>
> This will run the Docker instance as a daemon and expose port 5433 to the host system so that it looks like an ordinary PostgreSQL server to the rest of the system.

We don't *have* to use Docker to run Postgres (in fact, I'd normally advise against it), since NixOS already provides a Postgres NixOS module.  However, we can still use this as an illustrative example of how to translate Docker idioms to NixOS.

More generally, in this chapter we're going to cover container management in the context of NixOS and introduce a spectrum of options ranging from more Docker-native to more NixOS-native.

## Docker-native translation

We're going to begin from the previous chapter's example integration test:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.7#integration-test'
```

… but this time instead of using the NixOS `postgres` module:

```nix
# server.nix
…
    services.postgresql = {
      enable = true;

      # To match the tutorial
      port = 5433;

      initialScript = ./setup.sql;
    };
…
```

… we're going to replace that code with a NixOS configuration that runs the official `postgres` Docker container:

```nix
    virtualisation.oci-containers = {
      backend = "docker";

      containers."tutorial" = {
        image = "postgres:16.2";

        ports = [ "5433:5432" ];

        environment.POSTGRES_PASSWORD = "mysecretpassword";
      };
    };
```

{blurb, class:information}
Unlike the Postgrest tutorial, we're going to specify that we want to use a specific tag (version `16.2`) for the `postgres` container instead of using the default `latest` tag.  This improves the reproducibility of the example because the `latest` tag is a moving target whose behavior might want over time.
{/blurb}

This is similar to the original `docker run` command from the tutorial, except that instead of running the command verbatim we're translating the command to the equivalent NixOS options.  Specifically, NixOS provides a `virtualisation.oci-containers` option hierarchy which lets us declaratively define the same options as `docker run` but it also takes care of several supporting details for us, including:

- installing and running the `docker` service for our NixOS machine

  In particular, the `backend = "docker";` option is what specifies to use Docker as the backend for running our container (instead of the default backend, which is Podman).


- creating a Systemd service to start and stop the container

  This service essentially runs the same `docker run` command from the tutorial when starting, and also runs the matching `docker stop` command when stopping.

We also still need to run the setup commands from `setup.sql` after our container starts up, but we no longer have a convenient `services.postgresql.initialScript` option that we can use for this purpose when going the Docker route.  Instead, we're going to create our own "one shot" Systemd service to take care of this setup process for us:

```nix
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
$ nix flake check --print-build-logs
```
