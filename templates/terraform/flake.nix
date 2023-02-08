{ inputs.nixpkgs.url =
    "github:NixOS/nixpkgs/f1a49e20e1b4a7eeb43d73d60bae5be84a1e7610";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [ ./module.nix ];
    };
  };
}
