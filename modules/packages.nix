# System packages configuration module

{ pkgs, inputs, ... }:
let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  environment.systemPackages = with unstable; [
    emacs-nox
    cursor-cli

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
    deadnix # Nix dead code locator
    dig
    fd
    gh
    git
    k6
    nil # Nix language server
    nixd # Nix language server (with statix/deadnix support)
    nixfmt # Official RFC-166 Nix formatter
    nixpkgs-hammering # Linter for Nixpkgs packages
    nh # Nix Helper - nicer CLI for nixos-rebuild
    direnv # Environment switcher for shell
    nix-update # Swiss-knife for updating nix packages
    nix-init # Generator for Nix packages from URLs
    comma # Run software without installing it (, <pkg>)
    nftables
    rclone
    sops
    statix # Lints and suggestions for Nix
    tree

    # Shell and related tools
    shellcheck
    bubblewrap
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
