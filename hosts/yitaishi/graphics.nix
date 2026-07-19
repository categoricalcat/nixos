{
  pkgs,
  lib,
  ...
}:

{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      extraPackages = with pkgs.rocmPackages; [
        clr
        clr.icd
      ];
    };

    firmware = lib.mkBefore [ pkgs.linux-firmware ];

    amdgpu = {
      initrd.enable = true;
      opencl.enable = lib.mkForce false;

      overdrive = {
        enable = true;
        ppfeaturemask = "0xffffffff";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  nixpkgs.config.rocmSupport = true;
}
