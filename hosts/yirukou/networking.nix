{ addresses, ... }:

{
  networking = {
    inherit (addresses) hostName;
    networkmanager.enable = false;
    useDHCP = true;
    firewall.enable = true;
  };
}
