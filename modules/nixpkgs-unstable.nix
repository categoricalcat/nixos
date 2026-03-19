{ inputs, pkgs }:
import inputs.nixpkgs-unstable {
  system = pkgs.system;
  config.allowUnfree = true;
}
