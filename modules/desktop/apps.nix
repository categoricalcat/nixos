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
    unstable.onlyoffice-desktopeditors
    discord

    unstable.qbz

    wl-clipboard

    # (unstable.bitwarden-desktop.override { electron_39 = electron; })
    prismlauncher
    gimp
    nautilus
    unstable.vial
    unstable.obsidian
    unstable.obs-studio
    # unstable.nextcloud-client
  ];

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "vial-udev-rules";
      destination = "/etc/udev/rules.d/59-vial.rules";
      text = ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
      '';
    })
  ];
}
