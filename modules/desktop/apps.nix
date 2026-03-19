{ pkgs, inputs, ... }:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    google-chrome
    emacs-gtk

    unstable.vscode-fhs
    unstable.code-cursor-fhs
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
