{ pkgs, inputs, ... }:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    google-chrome # the bad
    emacs-gtk

    unstable.vscode-fhs
    unstable.code-cursor-fhs
    unstable.antigravity
    unstable.discord-ptb

    wl-clipboard

    unstable.bitwarden-desktop
    prismlauncher
    gimp
    nautilus
    unstable.vial
    unstable.obsidian
    # unstable.nextcloud-client
  ];
}
