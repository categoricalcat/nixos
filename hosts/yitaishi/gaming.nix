{ pkgs, ... }:
{
  hardware.fanatec.enable = true;

  # https://wiki.nixos.org/wiki/Category:Gaming
  programs = {
    gamemode.enable = true; # for performance mode

    steam = {
      enable = true; # install steam
      gamescopeSession.enable = true; # Enable gamescope micro-compositor for better AMD performance
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };

    # CoolerControl
    # A modern GUI daemon for viewing and controlling system temperatures and cooling devices.
    coolercontrol.enable = true;
  };

  environment.systemPackages = with pkgs; [
    heroic # install heroic launcher
    lutris # install lutris launcher
    protonup-qt # GUI for installing custom Proton versions like GE_Proton
  ];

  # Linux AMDGPU Controller (LACT)
  # A daemon and GUI for managing AMD Radeon GPUs on Linux.
  services.lact.enable = true;

  # AMDGPU overdrive is enabled in ./graphics.nix so LACT can control voltage,
  # clocks, and power limits.
}
