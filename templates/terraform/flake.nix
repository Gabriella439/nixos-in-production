{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.11";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [ ./module.nix ];
    };
  };
}
