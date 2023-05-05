{ services = {
    getty.autologinUser = "root";

    nginx = {
      enable = true;

      virtualHosts.localhost.locations."/" = {
        index = "index.html";

        root = "/var/www";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  virtualisation.forwardPorts = [
    { from = "host"; guest.port = 80; host.port = 8080; }
  ];

  virtualisation.sharedDirectories.www = {
    source = "$WWW";
    target = "/var/www";
  };

  system.stateVersion = "22.11";
}
