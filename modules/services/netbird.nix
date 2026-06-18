{ pkgs, ... }:
{
  services.netbird = {
    enable = true;
    package = pkgs.netbird;
  };

  networking.firewall.trustedInterfaces = [ "wt0" ];

  networking.firewall.extraInputRules = ''
    iifname "wt0" tcp dport { 139, 445 } accept
    iifname "wt0" udp dport { 137, 138 } accept
  '';
}
