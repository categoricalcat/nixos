# Main NixOS Configuration

{ config, pkgs, ... }:

{
  imports = [
    ./hardware/hardware-configuration.nix
    ./modules/boot.nix
    ./modules/locale.nix
    ./users/users.nix
    ./modules/packages.nix
    ./modules/networking.nix
    ./modules/network-performance.nix
    ./modules/usb-networking.nix
    ./modules/services.nix
    # ./modules/desktop.nix
    ./modules/server-settings.nix
    ./modules/server-mode.nix
    # ./home.nix
  ];

  serverMode.headless = true;

  # Nixpkgs configuration to handle deprecated packages
  nixpkgs.overlays = [
    (final: prev: {
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

  # NixOS version
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

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
  hardware.graphics = {
    enable = true;
  };

  # Create symlink for Ollama to find ROCm libraries
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.rocmPath}"
  ];
}
