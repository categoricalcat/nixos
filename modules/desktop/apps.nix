{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    google-chrome
    emacs-gtk

    vscode-fhs
    code-cursor-fhs
    cursor-cli
    antigravity

    wl-clipboard

    bitwarden-desktop
    prismlauncher
    discord-ptb
    gimp
    nautilus
    vial
  ];
}
