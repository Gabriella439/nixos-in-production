{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";

    sops-nix.url = "github:Mic92/sops-nix/bd695cc4d0a5e1bead703cc1bec5fa3094820a81";
  };

  outputs = { nixpkgs, sops-nix, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [ ./module.nix sops-nix.nixosModules.sops ];
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
}
