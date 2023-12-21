{ inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";

    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { flake-utils, nixpkgs, self }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";

      in
        { packages.default = pkgs.cowsay;

          apps = { 
            default = self.apps."${system}".cowsay;

            cowsay = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowsay";
            };

            cowthink = {
              type = "app";

              program = "${self.packages."${system}".default}/bin/cowthink";
            };
          };

          checks = {
            default = self.packages."${system}".default;

            diff = pkgs.runCommand "test-cowsay" { }
              ''
              diff <(${self.apps."${system}".default.program} howdy) - <<'EOF'
               _______ 
              < howdy >
               ------- 
                      \   ^__^
                       \  (oo)\_______
                          (__)\       )\/\
                              ||----w |
                              ||     ||
              EOF

              touch $out
              '';
          };

          devShells = {
            default = self.packages."${system}".default;

            with-dev-tools = pkgs.mkShell {
              inputsFrom = [ self.packages."${system}".default ];

              packages = [
                pkgs.vim
                pkgs.tree
              ];
            };
          };
        }) // {
          templates.default = {
            path = ./.;

            description = "A tutorial flake wrapping the cowsay package";
          };
        };
}
