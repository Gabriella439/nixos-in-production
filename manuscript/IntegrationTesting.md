{id: integration-testing}
# Integration testing

In [Our first web server](#hello-world) we covered how to test a server manually and in this chapter we'll go over how to use NixOS to automate this testing process.  Specifically, we're going to be authoring a NixOS test, which you can think of as the NixOS-native way of doing [integration testing](https://en.wikipedia.org/wiki/Integration_testing).  However, in this chapter we're going to depart from our running "TODO list" example[^1] and instead use NixOS tests to automate the Getting Started instructions from an open source tutorial.

Specifically, we're going to be testing the [PostgREST tutorial](https://postgrest.org/en/v12/tutorials/tut0.html).  You can read through the tutorial if you want, but the relevant bits are:

- Install Postgres (the database)

  Nixpkgs will handle this for us because Nixpkgs has already packaged `postgres` (both as a package and as a NixOS module for configuring `postgres`).


- Install PostgREST (the database-to-REST conversion service)

  Nixpkgs also (partially) handles this for us because all Haskell packages (including `postgrest`) are already packaged for us, but (at the time of this writing) there isn't yet a NixOS module for `postgres`.  For this particular example, though, that's fine because then the integration testing code will match the tutorial even more closely.


- Set up the database

  … by running these commands:

  ```sql
  create schema api;

  create table api.todos (
    id serial primary key,
    done boolean not null default false,
    task text not null,
    due timestamptz
  );

  insert into api.todos (task) values
    ('finish tutorial 0'), ('pat self on back');

  create role web_anon nologin;

  grant usage on schema api to web_anon;
  grant select on api.todos to web_anon;

  create role authenticator noinherit login password 'mysecretpassword';
  grant web_anon to authenticator;
  ```


- Launch PostgREST

  … with this configuration file:

  ```ini
  db-uri = "postgres://authenticator:mysecretpassword@localhost:5432/postgres"
  db-schemas = "api"
  db-anon-role = "web_anon"
  ```


- Check that the API works

  … by verifying that this command:

  ```bash
  $ curl http://localhost:3000/todos
  ```

  ```json
  [
    {
      "id": 1,
      "done": false,
      "task": "finish tutorial 0",
      "due": null
    },
    {
      "id": 2,
      "done": false,
      "task": "pat self on back",
      "due": null
    }
  ]
  ```

## NixOS test

You can clone the equivalent NixOS test by running:

```bash
$ nix flake init --template 'github:Gabriella439/nixos-in-production/0.9#integration-test'
```

One of the included files is `setup.sql` file which includes the database commands from the tutorial verbatim:

```sql
create schema api;

create table api.todos (
  id serial primary key,
  done boolean not null default false,
  task text not null,
  due timestamptz
);

insert into api.todos (task) values
  ('finish tutorial 0'), ('pat self on back');

create role web_anon nologin;

grant usage on schema api to web_anon;
grant select on api.todos to web_anon;

create role authenticator noinherit login password 'mysecretpassword';
grant web_anon to authenticator;
```

Similarly, another file is `tutorial.conf` which includes the PostgREST configuration from the tutorial verbatim:

```ini
db-uri = "postgres://authenticator:mysecretpassword@localhost:5432/postgres"
db-schemas = "api"
db-anon-role = "web_anon"
```

Now we need to wrap these two into a NixOS module which runs Postgres (with those setup commands) and PostgREST (with that configuration file), which is what `server.nix` does:

```nix
{ config, pkgs, ... }:

{ config = {
    networking.firewall.allowedTCPPorts = [ 3000 ];

    services.postgresql = {
      enable = true;

      initialScript = ./setup.sql;
    };

    systemd.services.postgrest = {
      wantedBy = [ "multi-user.target" ];

      after = [ "postgresql.service" ];

      path = [ pkgs.postgrest ];

      script = "postgrest ${./tutorial.conf}";

      serviceConfig.User = "authenticator";
    };

    users = {
      groups.database = { };

      users = {
        authenticator = {
          isSystemUser = true;

          group = "database";
        };
      };
    };
  };
}
```

The main extra thing we do here (that's not mentioned in the tutorial) is that we created an `authenticator` user and `database` group to match the database user of the same name.
Additionally, we open up port 3000 in the firewall, which we're going to need to do to test the PostgREST API (served on port 3000 by default).

We're also going to create a `client.nix` file containing a pretty bare NixOS configuration for our test client machine:

```nix
{ pkgs, ... }: {
  environment.defaultPackages = [ pkgs.curl ];
}
```

Next, we're going to write a Python script (`script.py`) to orchestrate our integration test:

```python
import json

start_all()

expected = [
    {"id": 1, "done": False, "task": "finish tutorial 0", "due": None},
    {"id": 2, "done": False, "task": "pat self on back", "due": None},
]

actual = json.loads(
    client.wait_until_succeeds(
        "curl --fail --silent http://server:3000/todos",
        55,
    )
)

assert expected == actual
```

This Python script logs into the `client` machine to run a `curl` command and compares the JSON output of the command against the expected output from the tutorial.

Finally, we tie this all together in `flake.nix`:

```nix
{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, self, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages = {
        inherit (self.checks.${system}.default) driverInteractive;
      };

      checks.default = nixpkgs.legacyPackages."${system}".nixosTest {
        name = "test";

        nodes = {
          server = import ./server.nix;

          client = import ./client.nix;
        };

        testScript = builtins.readFile ./script.py;
      };
    });
}
```

Here we're using the `nixosTest` function, which is our one-stop shop for integration testing.  This function takes two main arguments that we care about:

- `nodes`

  This is an attribute set with one attribute per machine that we want to test and each attribute contains a NixOS configuration for the corresponding machine.  Here, we're going to be testing two machines (named "server" and "client") whose NixOS configurations are going to be imported from `server.nix` and `client.nix` respectively.  We don't have to store these NixOS configurations in separate files (we could store them inline within this same `flake.nix` file), but the code is a bit easier to follow if we keep things separate.


- `testScript`

  This is our Python script that we're also going to store in a separate file (`script.py`).

Then we can run our NixOS test using:

```bash
$ nix flake check --print-build-logs
```

{blurb, class:information}
If you're on macOS you will need to follow the macOS-specific setup instructions from the [Setting up your development environment](#darwin-builder) chapter before you can run the above command.  In particular, you will need to have a Linux builder running in order to build the virtual machine image for the above NixOS test.
{/blurb}

## Interactive testing

You can also interactively run a NixOS test using a Python REPL that has access to the same commands available within our `script.py` test script.  To do so, run:

```bash
$ nix run '.#driverInteractive'
…
>>>
```

This will then open up a Python REPL with autocompletion support and the first thing we're going to do in this REPL is to launch all of the machines associated with our NixOS test (`server` and `client` in this case):

```python
>>> start_all()
```

Note that if you do this you won't notice the prompt (because it will be clobbered by the log output from the server), but it's still there.  Alternatively, you can prevent that by temporarily silencing the machine's log output like this:

```python
>>> serial_stdout_off()
>>> start_all()
start all VMs
client: starting vm
mke2fs 1.47.0 (5-Feb-2023)
client: QEMU running (pid 21160)
server: starting vm
mke2fs 1.47.0 (5-Feb-2023)
server: QEMU running (pid 21169)
(finished: start all VMs, in 0.38 seconds)
>>> serial_stdout_on()
```

These `serial_stdout_{on,off}` functions come in handy if you find the machine log output too noisy.

Once you've started up the machines you can begun running commands that interact with each machine by invoking methods on Python objects of the same name.

For example, you can run a simple `echo "Hello, world!"` command on the server machine like this:

```bash
>>> server.succeed('echo "Hello, world!"')
server: must succeed: echo "Hello, world!"
server: waiting for the VM to finish booting
server: Guest shell says: b'Spawning backdoor root shell...\n'
server: connected to guest root shell
server: (connecting took 0.00 seconds)
(finished: waiting for the VM to finish booting, in 0.00 seconds)
(finished: must succeed: echo "Hello, world!", in 0.04 seconds)
'Hello, world!\n'
```

… and the `succeed` method will capture the command's output and return it as a string which you can then further process within Python.

Now let's step through the same logic as the original test script so we can see for ourselves the intermediate values computed along the way:

```python
>>> response = client.succeed("curl --fail --silent http://server:3000/todos")
client: must succeed: curl --fail --silent http://server:3000/todos
(finished: must succeed: curl --fail --silent http://server:3000/todos, in 0.04 seconds)
>>> response
'[{"id":1,"done":false,"task":"finish tutorial 0","due":null}, \n {"id":2,"done":false,"task":"pat self on back","due":null}]'

>>> import json
>>> json.loads(response)
[{'id': 1, 'done': False, 'task': 'finish tutorial 0', 'due': None}, {'id': 2, 'done': False, 'task': 'pat self on back', 'due': None}]
```

This sort of interactive exploration really comes in handy when authoring the test for the first time since it helps you understand the shape of the data and figure out which commands you need to run.

You can consult the [NixOS test section of the NixOS manual](https://nixos.org/manual/nixos/stable/#ssec-machine-objects) if you need a full list of available methods that you can invoke on machine objects.  Some really common methods are:

- `succeed(command)` - Run a command once and require it to succeed
- `wait_until_succeeds(command, timeout)` - Keep running a command until it succeeds
- `wait_for_open_port(port, address, timeout)` - Wait for a service to open a port
- `wait_for_unit(unit, user, timeout)` - Wait for a Systemd unit to start up

… but there are also some really cool methods you can use like:

- `block()` - Simulate a network disconnect
- `crash()` - Simulate a sudden power failure
- `wait_for_console_text(regex, timeout)` - Wait for the given regex to match against any terminal output
- `get_screen_text()` - Use OCR to capture the current text on the screen

## Shared constants

There are several constants that we use repeatedly throughout our integration test, like:

- the PostgREST port
- the database, schema and table
- the username, role, group, and credentials

One advantage of codifying the tutorial as a NixOS test is that we can define constants like these in one place instead of copying them repeatedly and hoping that they remain in sync.  For example, we wouldn't want our integration test to break just because we changed the user's password in `setup.sql` and forgot to make the matching change to the password in `tutorial.conf`.  Integration tests can often be time consuming to run and debug, so we want our test to break for more meaningful reasons (an actual bug in the [system under test](https://en.wikipedia.org/wiki/System_under_test)) and not because of errors in the test code.

However, we're going to need to restructure things a little bit in order to share constants between the various test files.  In particular, we're going to be using NixOS options to store shared constants for reuse throughout the test.  To keep this example short, we won't factor out all of the shared constants and we'll focus on a turning a couple of representative constants into NixOS options.

First, we'll factor out the `"authenticator"` username into a shared constant, which we'll store as a `tutorial.username` NixOS option in `server.nix`:

```nix
{ lib, config, pkgs, ... }:

{ options = {
    tutorial = {
      user = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = {
    tutorial.user = "authenticator";

    systemd.services.postgrest = {
      …

      serviceConfig.User = config.tutorial.user;
    };

    users = {
      users = {
        "${config.tutorial.user}" = {
          isSystemUser = true;

          group = "database";
        };
      };
    };
  };
}
```

… and that fixes all of the occurrences of the `authenticator` user in `server.nix` but what about `setup.sql` or `tutorial.conf`?

One way to do this is to inline `setup.sql` and `tutorial.conf` into our `server.nix` file so that we can interpolate the NixOS options directly into the generated files, like this:

```nix
{ …

  config = {
    services.postgresql = {
      …

      initialScript = pkgs.writeText "setup.sql" ''
        create schema api;

        …

        create role ${config.tutorial.user} noinherit login password 'mysecretpassword';
        grant web_anon to ${config.tutorial.user};
      '';
    };

    systemd.services.postgrest = {
      …

      script =
        let
          configurationFile = pkgs.writeText "tutorial.conf" ''
            db-uri = "postgres://${config.tutorial.user}:mysecretpassword@localhost:5432/postgres"
            db-schemas = "api"
            db-anon-role = "web_anon"
          '';

        in
          "postgrest ${configurationFile}";

      …
    };

    …
  };
}
```

This solution isn't great, though, because it gets cramped pretty quickly and it's harder to edit inline Nix strings than standalone files.  For example, when `setup.sql` is a separate file many editors will enable syntax highlighting for those SQL commands, but that syntax highlighting won't work when the SQL commands are instead stored within an inline Nix string.

Alternatively, we can keep the files separate and use the [Nixpkgs `substituteAll` utility](https://nixos.org/manual/nixpkgs/stable/#fun-substituteAll) to interpolate the Nix variables into the file.  The way it works is that instead of using `${user}` to interpolate a variable you use `@user@`, like this new `tutorial.conf` file does:

```ini
db-uri = "postgres://@user@:mysecretpassword@localhost:5432/postgres"
db-schemas = "api"
db-anon-role = "web_anon"
```

Similarly, we change our `setup.sql` file to also substitute in `@user@` where necessary:

```sql
create schema api;

…

create role @user@ noinherit login password 'mysecretpassword';
grant web_anon to @user@;
```

Once we've done that we can use the `pkgs.substituteAll` utility to template those files with Nix variables of the same name:

```nix
{ …

  config = {
    …

    services.postgresql = {
      …

      initialScript = pkgs.substituteAll {
        name = "setup.sql";
        src = ./setup.sql;
        inherit (config.tutorial) user;
      };
    };

    systemd.services.postgrest = {
      …

      script =
        let
          configurationFile = pkgs.substituteAll {
            name = "tutorial.conf";
            src = ./tutorial.conf;
            inherit (config.tutorial) user;
          };

        in
          "postgrest ${configurationFile}";

      …
    };

    …
  };
}
```

The downside to using `pkgs.substituteAll` is that it's easier for there to be a mismatch between the variable names in the template and the variable names in Nix.  Even so, this is usually the approach that I would recommend.

We can do something fairly similar to also thread through the PostgREST port everywhere it's needed.  The original PostgREST tutorial doesn't specify the port in the `tutorial.conf` file, but we can add it for completeness:

```ini
db-uri = "postgres://@user@:mysecretpassword@localhost:5432/postgres"
db-schemas = "api"
db-anon-role = "web_anon"
server-port = @port@
```

… and then we can make matching changes to `server.nix` to define and use this port:

```nix
{ options = {
    tutorial = {
      port = lib.mkOption {
        type = lib.types.port;
      };

      …
    };
  };

  config = {
    tutorial.port = 3000;

    …

    networking.firewall.allowedTCPPorts = [ config.tutorial.port ];

    systemd.services.postgrest = {
      …

      script =
        let
          configurationFile = pkgs.substituteAll {
            name = "tutorial.conf";
            src = ./tutorial.conf;
            inherit (config.tutorial) port user;
          };

        in
          "postgrest ${configurationFile}";

      …
    };

    …
  };
}
```

… but we're not done!  We also need to thread this port to `script.py`, which references this same port in the `curl` command.

This might seem trickier because the place where `script.py` is referenced (in `flake.nix`):

```nix
{ …

  outputs = { flake-utils, nixpkgs, self, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      …

      checks.default = nixpkgs.legacyPackages."${system}".nixosTest {
        …

        testScript = builtins.readFile ./script.py;
      };
    });
}
```

… is not inside of any NixOS module.  So how do we access NixOS option definitions when defining our `testScript`?

The trick is that the `testScript` argument to the `nixosTest` function can be a function:

```nix
        # I've inlined the test script to simplify things
        testScript = { nodes }:
          let
            inherit (nodes.server.config.tutorial) port;

          in
            ''
            import json

            start_all()

            expected = [
                {"id": 1, "done": False, "task": "finish tutorial 0", "due": None},
                {"id": 2, "done": False, "task": "pat self on back", "due": None},
            ]

            actual = json.loads(
                client.wait_until_succeeds(
                    "curl --fail --silent http://server:${toString port}/todos",
                    7,
                )
            )

            assert expected == actual
            '';
```

This function takes one argument (`nodes`) which is an attribute set containing one attribute for each machine in our integration test (e.g. `server` and `client` for our example).  Each of these attributes in turn has all of the [output attributes generated by `evalModules`](https://github.com/NixOS/nixpkgs/blob/23.11/lib/modules.nix#L317-L324), including:

- `options` - the option declarations for the machine
- `config` - the final option definitions for the machine

This is why we can access the server's `tutorial.port` NixOS option using `nodes.server.config.tutorial.port`.

Moreover, every NixOS configuration also has a `nixpkgs.pkgs` option storing the NixOS package set used by that machine.  This means that instead of adding `curl` to our `client` machine's `environment.defaultPackages`, we could instead do something like this:

```nix
        testScript = { nodes }:
          let
            inherit (nodes.client.config.nixpkgs.pkgs) curl;

            …

          in
            ''
            …

            actual = json.loads(
                client.wait_until_succeeds(
                    "${curl}/bin/curl --fail --silent http://server:${toString port}/todos",
                    7,
                )
            )

            …
            '';
```

[^1]: The reason why is that writing a (meaningful) test for our TODO list example would require executing JavaScript using something like Selenium, which will significantly increase the size of the example integration test.  `postgrest`, on the other hand, is easier to test from the command line.
