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

    # System utilities
    # rocmSupport=true patches in the rpath so btop dlopens librocm_smi64
    # and shows the AMD iGPU. Without it, btop builds CPU-only.
    amdgpu_top
    curl
    stow
    wget

    # Development tools
    deadnix
    dig
    fd
    gh
    git
    k6
    nil
    nixd
    nixfmt
    nftables
    rclone
    sops
    statix
    tree

    # Shell and related tools
    shellcheck

    bat
    brotli
    ethtool
    iftop
    iperf3
    jq
    kubectl
    ncdu
    nethogs
    nmap
    python3
    screen
    systemd
    tcpdump
    traceroute
    # unstable.bitwarden-cli
    ripgrep
  ];
}
