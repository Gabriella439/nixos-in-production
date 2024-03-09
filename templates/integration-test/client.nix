{ pkgs, ... }: {
  environment.defaultPackages = [ pkgs.curl ];
}
