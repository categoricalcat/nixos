_:

{
  networking.enableIPv6 = true;
  networking.tempAddresses = "disabled";
  systemd.network.config.networkConfig.IPv6PrivacyExtensions = false;

  environment.etc."gai.conf".text = ''
    precedence ::1/128                50
    precedence fd75:c55f:6d19::/48    45
    precedence ::ffff:0:0/96          40
    precedence ::/0                   30
    precedence 2002::/16              20
    precedence 2001::/32               5
    precedence fd7a:115c:a1e0::/48     3
    precedence fc00::/7                 3
    precedence ::/96                    1
  '';
}
