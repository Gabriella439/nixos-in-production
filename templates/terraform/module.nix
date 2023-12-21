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
}
