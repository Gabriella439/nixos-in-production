{ modulesPath, ... }:

{ imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  documentation.enable = false;

  services.nginx = {
    enable = true;

    virtualHosts.localhost.locations."/" = {
      index = "index.html";

      root = ./www;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  system.stateVersion = "23.05";

  sops = {
    defaultSopsFile = ./secrets.yaml;

    age.sshKeyPaths = [ "/var/lib/id_ed25519" ];

    secrets.github-access-token = { };
  };

  nix.extraOptions = "!include /run/secrets/github-access-token";

  nix.settings.extra-experimental-features = [ "nix-command" "flakes" ];

  system.autoUpgrade = {
    enable = true;

    # Replace ${username}/${repository} with your repository's address
    flake = "github:${username}/${repository}#default";

    # Poll the `main` branch for changes once a minute
    dates = "minutely";

    # You need this if you poll more than once an hour
    flags = [ "--option" "tarball-ttl" "0" ];
  };
}
