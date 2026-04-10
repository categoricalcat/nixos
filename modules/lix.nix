{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  unstablePkgs = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  nix.package = lib.mkForce unstablePkgs.lix;
}
