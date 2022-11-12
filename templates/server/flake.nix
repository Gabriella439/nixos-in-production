{ inputs = {
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";

    nixpkgs.url = "github:NixOS/nixpkgs/f1a49e20e1b4a7eeb43d73d60bae5be84a1e7610";
  };

  outputs = { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

        base = { lib, modulesPath, ... }: {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          # https://github.com/utmapp/UTM/issues/2353
          networking.nameservers = lib.mkIf pkgs.stdenv.isDarwin [ "8.8.8.8" ];

          virtualisation = {
            graphics = false;

            host = { inherit pkgs; };
          };
        };

        machine = nixpkgs.lib.nixosSystem {
          system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;

          modules = [ base ./module.nix ];
        };

        program = pkgs.writeShellScript "run-vm.sh" ''
          export NIX_DISK_IMAGE=$(mktemp -u -t nixos.qcow2)

          trap "rm -f $NIX_DISK_IMAGE" EXIT

          ${machine.config.system.build.vm}/bin/run-nixos-vm
        '';

      in
        { packages = { inherit machine; };

          apps.default = {
            type = "app";

            program = "${program}";
          };
        }
    );
}
