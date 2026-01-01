{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:

let
  desktopEnvironment = "niri";
in
{
  imports = [
    ../../modules/services/nfs/client.nix
    ./boot.nix
    ./hardware.nix
    ./power.nix
    ../../secrets/sops.nix
    ../../modules/packages.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/desktop.nix
    ../../modules/services/tlp.nix
    ../../users/users.nix
    # ../../modules/services/synergy.nix
    ./networking.nix
  ];

  environment.systemPackages = [ pkgs.mprisence ];

  desktop.environment = desktopEnvironment;

  system.stateVersion = "26.05";

  programs.nix-ld.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = false;
  };

  nix = {
    distributedBuilds = true;

    buildMachines =
      let
        mkBuildMachine = hostName: {
          inherit hostName;
          system = "x86_64-linux";
          maxJobs = 15;
          speedFactor = 3;
          protocol = "ssh-ng";
          supportedFeatures = [
            "nixos-test"
            "benchmark"
            "big-parallel"
            "kvm"
          ];
          sshUser = config.users.users.fufud.name;
          sshKey = "/home/fufud/.ssh/id_ed25519";
        };
      in
      [
        (mkBuildMachine "fufud.vpn")
        # (mkBuildMachine "ssh.fufu.land")
      ];

    extraOptions = ''
      connect-timeout = 5
    '';

    settings = {
      trusted-users = [
        "root"
        config.users.users.fufud.name
      ];

      builders-use-substitutes = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      download-buffer-size = 1024 * 1024 * 1024 * 10;

      substituters = [
        "https://nix-community.cachix.org"
        "https://nixos-rocm.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit desktopEnvironment inputs;
    };
    users.fufud = import ../../users/home-fufud.nix;
    backupFileExtension = "bkp";
    overwriteBackup = true;
  };

  services.openssh = {
    enable = true;
    listenAddresses = [
      # { addr = "fuyidong.local"; }
      { addr = "10.100.0.2"; }
    ];
  };

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = lib.mkDefault true;
  security.pam.services.gdm-fingerprint.fprintAuth = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    intel-gpu-tools.enable = true;
    bluetooth.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        vpl-gpu-rt
        intel-media-driver
        intel-gpu-tools
      ];
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 75;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 100;
    "vm.page-cluster" = 0;
  };
}
