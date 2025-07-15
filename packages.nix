# System packages configuration module

{ config, pkgs, ... }:

{
  # System-wide packages
  environment.systemPackages = with pkgs; [
    # System utilities
    btop
    curl
    wget
    fastfetch # System information tool

    # Development tools
    emacs
    git
    gh
    nixfmt-rfc-style
    direnv  # Automatic environment switching
    vscode-fhs # Using vscode-fhs instead of vscode to avoid deprecated dependencies
    
    nodejs_20  # Node.js 20.x LTS
    
    # Node.js version manager
    # fnm  # Fast Node Manager - nvm alternative for NixOS
    
    # Global npm packages (the NixOS way)
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
  ];
}
