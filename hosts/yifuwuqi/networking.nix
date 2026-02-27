{ addresses, ... }:
{
  imports = [
    ../../modules/networking/firewall.nix
    ../../modules/networking/interfaces/bond0.nix
    ../../modules/networking/interfaces/wg0.nix
    ../../modules/networking/interfaces/wlp2s0.nix
    ../../modules/networking/tweaks.nix
  ];

  services.resolved = {
    enable = false;
  };

  networking = {
    inherit (addresses) hostName;

    nameservers = addresses.dns.systemNameservers;

    enableIPv6 = true;
    tempAddresses = "disabled";

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = true;
  };

  environment.etc."gai.conf".text = ''
    # Prefer IPv6 over IPv4 for address selection
    # See gai.conf(5) for details
    precedence ::1/128       50     # localhost (IPv6)
    precedence ::/0          40     # IPv6 global
    precedence ::ffff:0:0/96 30     # IPv4-mapped IPv6
    precedence 2002::/16     20     # 6to4
    precedence 2001::/32     5      # Teredo
    precedence fc00::/7      3      # ULA
    precedence ::/96         1      # IPv4-compatible IPv6
    precedence ::1/128       50     # localhost
  '';
}
