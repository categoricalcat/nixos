{ pkgs, ... }:
{
  # https://wiki.nixos.org/wiki/Category:Gaming
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true; # install steam
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  hardware.steam-hardware.enable = true;

  environment.systemPackages = with pkgs; [
    # heroic # install heroic launcher  # uses insecure pnpm at build time
    lutris # install lutris launcher
    protonup-qt # GUI for installing custom Proton versions like GE_Proton
  ];
}
