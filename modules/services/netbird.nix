{ pkgs, inputs, ... }:
let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  services.netbird = {
    enable = true;
    package = unstable.netbird;
  };

  networking.firewall.trustedInterfaces = [ "wt+" ];

  # SMB ports on Netbird
  networking.firewall.extraInputRules = ''
    iifname "wt*" tcp dport { 139, 445 } accept
    iifname "wt*" udp dport { 137, 138 } accept
  '';
}
