{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, self, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages = {
        inherit (self.checks.${system}.default) driverInteractive;
      };

      checks.default = nixpkgs.legacyPackages."${system}".nixosTest {
        name = "test";

        nodes = {
          server = import ./server.nix;

          client = import ./client.nix;
        };

        testScript = builtins.readFile ./script.py;
      };
    });
}
