# Main NixOS Configuration

{ config, pkgs, ... }:

{
  imports = [
    ./hardware/fufuwuqi.nix
    ./modules/addresses.nix
    ./modules/boot.nix
    ./modules/locale.nix
    ./users/users.nix
    ./modules/packages.nix
    ./modules/networking.nix
    ./modules/services/services.nix
    # ./modules/desktop.nix
    ./modules/server-settings.nix
    ./modules/server-mode.nix
    ./secrets/sops.nix
  ];

  serverMode.headless = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = true;
  };

  system.stateVersion = "25.11";

  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "Maple Mono NF CN"
        ];
        sansSerif = [
          "Maple Mono NF CN"
        ];
        serif = [
          "Maple Mono NF CN"
        ];
      };

      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };

    fontDir.enable = true;
    enableDefaultPackages = true;

    packages = with pkgs; [
      maple-mono.NF-CN
    ];
  };

  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.amdvlk.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
  };

  security.tpm2 = {
    enable = true;
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.rocmPath}"
  ];
}
