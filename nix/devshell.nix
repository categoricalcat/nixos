# Development shell configuration
{
  system,
  nixpkgs,
  pre-commit-check,
}:

let
  pkgs = import nixpkgs { inherit system; };
in
pkgs.mkShell {
  inherit (pre-commit-check) shellHook;

  packages = with pkgs; [
    udev
  ];
}
