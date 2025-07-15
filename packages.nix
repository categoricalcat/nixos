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

    # Security tools
    google-authenticator

    # Shell and related tools
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
  ];
}
