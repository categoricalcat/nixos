{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord
    discord-canary
    chromium
    # firefox
    vscode-fhs
    code-cursor-fhs
    spotifyd
    zsh
    bitwarden-desktop
    git
    kitty
    ghostty
    cloudflared
    xdg-desktop-portal-gtk
    gimp
  ];
}
