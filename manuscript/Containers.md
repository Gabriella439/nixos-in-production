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

We don't *have* to use Docker to run Postgres (in fact, I'd normaly advise against it), since NixOS already provides a Postgres NixOS module.  However, we can still use this as an illustrative example of how to translate Docker idioms to NixOS.

More generally, in this chapter we're going to cover container management in the context of NixOS and introduce a spectrum of options ranging from more Docker-native to more NixOS-native.

## Docker-native translation

We can translate the above `docker run` command fairly faithfully to an equivalent NixOS configuration by starting from the previous chapter's example:
The most direct way to translate the above `docker` command to a 
