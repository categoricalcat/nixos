{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    emacs-gtk

    pkgs.vscode-fhs
    pkgs.code-cursor-fhs
    pkgs.antigravity
    pkgs.onlyoffice-desktopeditors
    discord
    pkgs.vesktop

    pkgs.qbz

    wl-clipboard

    # (pkgs.bitwarden-desktop.override { electron_39 = electron; })
    prismlauncher
    gimp
    nautilus
    pkgs.vial
    pkgs.obsidian
    pkgs.mangohud
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        obs-vkcapture
        obs-vaapi
        obs-gstreamer
      ];
    })
    pkgs.obs-studio-plugins.obs-vkcapture
    # pkgs.nextcloud-client
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
