{ config, pkgs, ... }:

{ config = {
    networking.firewall.allowedTCPPorts = [ 3000 ];

    virtualisation.oci-containers = {
      backend = "docker";

      containers = {
        tutorial = {
          image = "postgres:16.2";

          environment.POSTGRES_PASSWORD = "mysecretpassword";

          extraOptions = [ "--network=host" ];
        };

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

    systemd.services.docker-postgrest.after = [ "setup-postgresql.service" ];

    users = {
      groups.database = { };

      users.authenticator = {
        isSystemUser = true;

        group = "database";
      };
    };
  };
}
