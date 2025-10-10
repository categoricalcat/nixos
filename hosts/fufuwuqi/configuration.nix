# Main NixOS Configuration (host: fufuwuqi)

{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./addresses.nix
    ./boot.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../users/users.nix
    ../../modules/packages.nix
    ./networking.nix
    ./services.nix
    # ../../modules/desktop.nix
    ../../modules/server-settings.nix
    ../../modules/server-mode.nix
    ../../secrets/sops.nix
  ];

  serverMode.headless = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    download-buffer-size = 1073741824;
  };

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = true;
  };

  system.stateVersion = "25.11";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics.enable = true;

    amdgpu = {
      opencl.enable = true;
      # amdvlk.enable = true;
    };
  };

  security.tpm2 = {
    enable = true;
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.rocmPath}"
  ];

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      desktopEnvironment = null; # server/headless
    };
    users.fufud = import ../../users/home-fufud.nix;
    users.workd = import ../../users/home-workd.nix;
  };
}
