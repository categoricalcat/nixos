{
  pkgs,
  lib,
  ...
}:

{
  # zen 7.3.4 (linuxPackages_zen) panics before journald on this host; the
  # vanilla kernel of the same version boots.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # system.boot.loader.kernelFile = "vmlinuz";

  # Bypasses the CAP_SYS_NICE check in AMDGPU to enable high-priority contexts
  # (asynchronous reprojection) inside the unprivileged Steam bubblewrap sandbox.
  # NOTE: Enabling this will trigger a full kernel build from source.
  #
  # boot.kernelPatches = [
  #   {
  #     name = "amdgpu-ignore-ctx-privileges";
  #     patch = pkgs.fetchpatch {
  #       name = "cap_sys_nice_begone.patch";
  #       url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
  #       hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
  #     };
  #   }
  # ];

  boot = {
    loader = {
      timeout = 1;
      systemd-boot.configurationLimit = 10;
      systemd-boot.enable = lib.mkForce false;
      grub.enable = false;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    initrd.systemd.settings.Manager = {
      DefaultTimeoutStopSec = "10s";
    };
    initrd.systemd.tpm2.enable = false;

    kernelModules = lib.mkAfter [
      "fuse"
      "k10temp"
      "nct6775"
    ];

    kernelParams = [
      "amd_pstate=active"
    ];

    extraModprobeConfig = ''
      options snd_usb_audio implicit_fb=1
    '';
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
