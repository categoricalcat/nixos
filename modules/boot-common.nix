{ inputs, pkgs, ... }:

let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
    };
  };

  boot.kernelPackages = unstable.linuxPackages_latest;
}
