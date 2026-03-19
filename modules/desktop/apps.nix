{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good

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
    gimp
    nautilus
    zerotierone
    vial
  ];
}
