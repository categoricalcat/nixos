{ pkgs, ... }:
{
  hardware.fanatec.enable = true;

  # https://wiki.nixos.org/wiki/Category:Gaming
  programs.gamemode.enable = true; # for performance mode

  programs.steam = {
    enable = true; # install steam
    gamescopeSession.enable = true; # Enable gamescope micro-compositor for better AMD performance
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [
    heroic # install heroic launcher
    lutris # install lutris launcher
    protonup-qt # GUI for installing custom Proton versions like GE_Proton
  ];

  # CoolerControl
  # A modern GUI daemon for viewing and controlling system temperatures and cooling devices.
  programs.coolercontrol.enable = true;

  # Linux AMDGPU Controller (LACT)
  # A daemon and GUI for managing AMD Radeon GPUs on Linux.
  services.lact.enable = true;

  # Enable AMDGPU overdrive in the kernel to allow full control
  # over voltage, clocks, and power limits via LACT.
  # hardware.amdgpu.overdrive.enable = true; # Not available in standard NixOS 25.11 module yet, usually handled by lact module or kernel params.
  # We will rely on services.lact.enable and the boot.kernelParams.
}
