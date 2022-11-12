{ outputs = { self }: {
    templates = {
      setup = {
        path = ./templates/setup;
        description = "A flake you can use to launch a NixOS VM";
      };

      server = {
        path = ./templates/server;
        description = "A prototype TODO list web application";
      };
    };
  };
}
