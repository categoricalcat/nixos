{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord-ptb
    chromium
    floorp-bin
    vscode-fhs
    code-cursor-fhs
    spotifyd
    zsh
    bitwarden-desktop
    git
    kitty
    ghostty
    cloudflared
    gimp
    antigravity
    wl-clipboard
  ];
}
