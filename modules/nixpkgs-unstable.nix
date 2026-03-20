{ inputs, pkgs }:
import inputs.nixpkgs-unstable {
  inherit (pkgs) system;
  config.allowUnfree = true;
}
