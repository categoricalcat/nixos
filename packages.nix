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
    fd  # Fast file finder, works well with fzf

    # Container tools (Podman)
    buildah         # Container image builder (docker buildx alternative)
    
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
    starship
    fzf
    zoxide

    maple-mono.NF-CN

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
