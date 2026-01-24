{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord-ptb
    chromium
    floorp-bin-unwrapped
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
    antigravity
    wl-clipboard
  ];
}
