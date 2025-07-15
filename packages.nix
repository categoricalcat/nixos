# System packages configuration module

{ config, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-wide packages
  environment.systemPackages = with pkgs; [
    # System utilities
    btop
    curl
    wget

    # Development tools
    emacs
    git
    gh
    nixfmt-rfc-style
    # nodejs_24
    vscode

    # Security tools
    google-authenticator

    # Shell and related tools
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
  ];
}
