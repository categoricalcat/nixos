# System packages configuration module (Universal Base)
#
# Only what a host genuinely needs outside a login shell: root deploys and
# edits secrets here directly. Everything interactive lives in `nix develop`
# and `yi`'s Home Manager profile (nix/cli-tools.nix); nftables, curl and zsh
# arrive through their own modules.

{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.git
    pkgs.sops
  ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 2d --keep 2";
    flake = "/home/yi/the.files/nixos";
  };
}
