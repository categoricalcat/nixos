# System packages configuration module

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # System utilities
    btop
    curl
    wget
    fastfetch
    tmux
    stow

    # Development tools
    rclone
    emacs
    git
    gh
    nixfmt-rfc-style
    direnv
    vscode-fhs
    tree

    # node stuff
    nodejs_latest
    # fnm
    nodePackages.pnpm
    nodePackages.eslint
    nodePackages.typescript
    nodePackages.npm-check-updates

    # Security tools
    google-authenticator

    # Shell and related tools
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting

    maple-mono.NF-CN-unhinted

    # ROCm packages for GPU compute
    rocmPackages.clr
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    rocmPackages.rocmPath
    rocmPackages.hipblas
    rocmPackages.rocblas
    rocmPackages.rocsolver
  ];
}
