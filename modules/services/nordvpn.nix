{ lib, ... }:
{
  services.nordvpn.enable = true;

  # Allow user `yi` to communicate with the NordVPN daemon socket (/run/nordvpn/nordvpnd.sock)
  users.users.yi.extraGroups = [ "nordvpn" ];

  # Loose reverse path filtering is required for VPN routing
  networking.firewall.checkReversePath = lib.mkDefault "loose";
}
