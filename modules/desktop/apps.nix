{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    google-chrome # the bad

    vscode-fhs
    code-cursor-fhs
    antigravity

    zsh
    git
    wl-clipboard

    bitwarden-desktop
    prismlauncher
    discord-ptb
    cloudflared
    tidal-hifi
    gimp
    nemo
    zerotierone
    vial
  ];
}
