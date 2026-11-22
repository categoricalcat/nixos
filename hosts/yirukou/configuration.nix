{
  config,
  global,
  pkgs,
  ...
}:

{
  imports = [
    ./boot.nix
    ./services.nix
    ./hardware.nix
    ./networking.nix
    ../../users/users.nix
    ../../secrets/sops.nix
    ../../modules/common.nix
    ../../modules/locale.nix
    ../../modules/nix-settings.nix
    ../../modules/server-settings.nix
    ../../modules/networking/ipv6.nix
  ];

  system = {
    stateVersion = global.version;
    disableInstallerTools = true;
    tools.nixos-version.enable = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  zramSwap.enable = false;
  yi.ssh.permitRootKeyLogin = true;

  # Appliance profile: omit Home Manager, extra shells, nix-ld, and docs;
  # ad-hoc dev/repo tools are loaded on demand via `nix develop`.
  environment.systemPackages = with pkgs; [
    curl
    dig
    jq
  ];

  programs = {
    zsh.enable = false;
    nix-ld.enable = false;
    command-not-found.enable = false;
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  xdg = {
    mime.enable = false;
    icons.enable = false;
    autostart.enable = false;
    menus.enable = false;
    portal.enable = false;
  };

  fonts.fontconfig.enable = false;

  nix.gc = {
    automatic = true;
    dates = config.yi.maintenance.slots.nixGc.calendar;
    options = "--delete-older-than 7d";
  };
  systemd.timers.nix-gc.timerConfig = config.yi.maintenance.slots.nixGc.timerConfig;
}
