{ config, pkgs, ... }:

{ config = {
    networking.firewall.allowedTCPPorts = [ 3000 ];

    services.postgresql = {
      enable = true;

      # To match the tutorial
      port = 5433;

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
      groups."database" = { };

      users = {
        "authenticator" = {
          isSystemUser = true;
          group = "database";
        };
      };
    };
  };
}
