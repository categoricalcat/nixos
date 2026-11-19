{
  pkgs,
  lib,
  ...
}:
let
  # ROCm OpenCL runtime + ICD, shared by the stable-mesa fallback and the
  # mesa-git default set (chaotic mkForce-replaces hardware.graphics.extraPackages).
  rocmOpencl = [
    pkgs.rocmPackages.clr
    pkgs.rocmPackages.clr.icd
  ];
in
{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      extraPackages = rocmOpencl;
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

  # Mesa main (chaotic-nyx, binary-cached) as the default driver set. The
  # module's fallbackSpecialisation keeps a stable-mesa boot entry for
  # recovery from upstream regressions.
  chaotic.mesa-git = {
    enable = true;
    # The module force-replaces extraPackages, so the gamescope WSI layer
    # (programs.gamescope.enableWsi) must be restated here.
    extraPackages = rocmOpencl ++ [ pkgs.gamescope-wsi ];
    extraPackages32 = [ pkgs.pkgsi686Linux.gamescope-wsi ];
  };

  system.nixos.tags = [ "mesa-git" ];

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  nixpkgs.config.rocmSupport = true;
}
