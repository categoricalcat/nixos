{ pkgs, ... }:

{
  imports = [
    ../../modules/services/openssh.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/samba/client.nix
  ];

  services.xserver = {
    enable = true;
    desktopManager.lxqt.enable = true;
    displayManager.sddm.enable = true;
  };

  environment.systemPackages = with pkgs; [
    firefox
  ];
}
