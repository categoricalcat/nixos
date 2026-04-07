{ inputs, pkgs }:
import inputs.nixpkgs-unstable {
  inherit (pkgs.stdenv.hostPlatform) system;
  config.allowUnfree = true;
}
