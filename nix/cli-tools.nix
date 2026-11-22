# Interactive CLI suite shared by `nix develop` and Home Manager, so the
# system profile stays lean and the two consumers cannot drift.
{ pkgs }:
[
  pkgs.bat
  pkgs.dig
  pkgs.fd
  pkgs.jq
  pkgs.killall
  pkgs.ncdu
  pkgs.p7zip
  pkgs.pik
  pkgs.ripgrep
  pkgs.stow
  pkgs.tree
  pkgs.unzip
  pkgs.wget
  pkgs.zip
  # Manual secrets.md host-key checks need this outside the devshell,
  # same rationale as keeping sops in modules/packages.
  pkgs.ssh-to-age
]
