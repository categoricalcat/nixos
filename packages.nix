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
    # nodejs_24
    vscode-fhs # Using vscode-fhs instead of vscode to avoid deprecated dependencies
    
    # Node.js versions - uncomment the one you need
    # nodejs_18  # Node.js 18.x LTS
    nodejs_20  # Node.js 20.x LTS
    # nodejs_22  # Node.js 22.x (current)
    # nodejs_24  # Node.js 24.x (latest)
    
    # Node.js version manager
    fnm  # Fast Node Manager - nvm alternative for NixOS

    # Security tools
    google-authenticator

    # Shell and related tools
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
  ];
}
