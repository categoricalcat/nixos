# System packages configuration module

{ pkgs, inputs, ... }:
let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  environment.systemPackages = with pkgs; [
    emacs-nox
    unstable.cursor-cli

    gcc
    gnumake
    killall
    zsh
    cloudflared
    zerotierone

    # System utilities
    btop
    curl
    stow
    tmux
    wget

    # Development tools
    deadnix
    dig
    direnv
    fd
    gh
    git
    k6
    nil
    nix-direnv
    nixfmt
    nftables
    rclone
    sops
    statix
    tree

    # Shell and related tools
    shellcheck
    fzf
    starship
    zoxide

    bat
    brotli
    ethtool
    iftop
    iperf3
    kubectl
    ncdu
    nethogs
    nmap
    python3
    screen
    systemd
    tcpdump
    traceroute
    unstable.bitwarden-cli
    wireguard-tools
  ];
}
