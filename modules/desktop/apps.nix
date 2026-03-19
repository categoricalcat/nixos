{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    google-chrome

    vscode-fhs
    code-cursor-fhs
    cursor-cli
    antigravity

    zsh
    git
    wl-clipboard

    bitwarden-desktop
    prismlauncher
    discord-ptb
    cloudflared
    gimp
    nautilus
    zerotierone
    vial
  ];
}
