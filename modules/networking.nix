_:

let
  dnsServers = [
    "2001:4860:4860::8888" # Google IPv6 DNS
    "2606:4700:4700::1111" # Cloudflare IPv6 DNS
    "8.8.8.8" # Google IPv4 DNS
    "1.1.1.1" # Cloudflare IPv4 DNS
  ];
in
{
  _module.args.dnsServers = dnsServers;

  imports = [
    ./networking/firewall.nix
    ./networking/interfaces.nix
    ./networking/tweaks.nix
  ];

  services.resolved = {
    enable = true;
    dnsovertls = "opportunistic";
    dnssec = "allow-downgrade";
    fallbackDns = dnsServers;
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=yes
    '';
  };

  networking = {
    hostName = "fufuwuqi";

    nameservers = dnsServers;

    enableIPv6 = true;
    tempAddresses = "enabled";

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    hosts = {
      "2804:41fc:802d:52f1::1" = [
        "fufuwuqi.vpn"
      ];
      "10.100.0.1" = [
        "fufuwuqi.vpn"
      ];
      "127.0.0.1" = [
        "fufuwuqi.local"
        "localhost"
      ];
      "::1" = [
        "fufuwuqi.local"
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
