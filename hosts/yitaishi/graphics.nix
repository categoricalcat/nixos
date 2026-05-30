{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with unstable.rocmPackages; [
        clr
        clr.icd
      ];
    };

    firmware = lib.mkBefore [ unstable.linux-firmware ];

    amdgpu = {
      initrd.enable = true;
      opencl.enable = lib.mkForce false;

      overdrive = {
        enable = true;
        ppfeaturemask = "0xffffffff";
      };
    };
  };
}
