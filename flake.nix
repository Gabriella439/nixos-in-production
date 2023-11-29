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

      terraform = {
        path = ./templates/terraform;
        description = "A terraform project to deploy the web application";
      };

      continuous-deployment = {
        path = ./templates/continuous-deployment;
        description = "A flake for continuous integration and continuous deployment";
      };
    };
  };
}
