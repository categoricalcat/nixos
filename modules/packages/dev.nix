# Developer, Nix, cloud & compiler tooling module

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cursor-cli
    gcc
    gnumake
    cloudflared
    deadnix
    gh
    k6
    nil
    nixd
    nixfmt
    nixpkgs-hammering
    direnv
    nix-update
    nix-init
    comma
    rclone
    statix
    treefmt
    shellcheck
    shfmt
    shellharden
    bubblewrap
    kubectl
    python3
    screen
    systemd
  ];
}
