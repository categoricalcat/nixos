{ addresses, ... }:

{
  _module.args.systemNameservers = addresses.dns.systemNameservers;
  _module.args.upstreamDnsServers = addresses.dns.upstreamDnsServers;

  imports = [
    ./networking/firewall.nix
    ./networking/interfaces.nix
    ./networking/tweaks.nix
  ];

  services.resolved = {
    enable = true;
    dnsovertls = "opportunistic";
    dnssec = "allow-downgrade";
    fallbackDns = addresses.dns.upstreamDnsServers;
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=yes
    '';
  };

  networking = {
    inherit (addresses) hostName;

    nameservers = addresses.dns.upstreamDnsServers;

    enableIPv6 = true;
    tempAddresses = "disabled";

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    hosts = {
      "${addresses.network.vpn.ipv6.host}" = [
        "${addresses.hostName}.${addresses.dns.domain}"
      ];
      "${addresses.network.vpn.ipv4.host}" = [
        "${addresses.hostName}.${addresses.dns.domain}"
      ];
      "127.0.0.1" = [
        "${addresses.hostName}.local"
        "localhost"
      ];
      "::1" = [
        "${addresses.hostName}.local"
        "localhost"
      ];
    };
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
