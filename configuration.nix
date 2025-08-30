# Main NixOS Configuration

{ config, pkgs, ... }:

{
  imports = [
    ./hardware/fuwuqi.nix
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

  # Nixpkgs configuration to handle deprecated packages
  nixpkgs.overlays = [
    (_final: prev: {
      androidndkPkgs_23b = prev.androidndkPkgs_23;
    })
  ];

  # experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Suppress CUDA warnings by setting minimum version
  nixpkgs.config = {
    allowUnfree = true; # Allow unfree packages
    cudaSupport = false; # Disable CUDA support (NVIDIA-only, not needed for AMD)
    # For AMD GPU compute support, you would use ROCm instead:
    rocmSupport = true; # Enable if you need AMD GPU compute support
  };

  system.stateVersion = "25.11";

  # Font configuration
  fonts = {
    # Enable font management
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

      # Better font rendering
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

  # Create symlink for Ollama to find ROCm libraries
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.rocmPath}"
  ];
}
