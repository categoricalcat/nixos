{ pkgs, ... }:

let
  desktopEnvironment = "gnome";
in
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ../../secrets/sops.nix
    ../../modules/packages.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/desktop.nix
    ../../modules/services/battery.nix
    ../../users/users.nix
  ];

  desktop.environment = desktopEnvironment;

  system.stateVersion = "25.11";

  programs.nix-ld.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    download-buffer-size = 1024 * 1024 * 1024 * 10;
    # substituters = [
    #   "https://nix-community.cachix.org"
    #   "https://cache.nixos.org/"
    # ];
  };

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit desktopEnvironment;
    };
    users.fufud = import ../../users/home-fufud.nix;
    backupFileExtension = "hm-backup";
  };

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver
    ];
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 80;
  };

  zramSwap = {
    enable = false;
    algorithm = "zstd"; # Offers a good balance of compression speed and ratio
    memoryPercent = 50; # This will reserve 50% of your 15GB (about 7.5GB) for zram
  };
}
