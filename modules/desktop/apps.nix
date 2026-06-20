{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good
    emacs-gtk

    vscode-fhs
    code-cursor-fhs
    antigravity
    onlyoffice-desktopeditors
    discord
    vesktop

    qbz

    wl-clipboard

    # (bitwarden-desktop.override { electron_39 = electron; })
    prismlauncher
    gimp
    nautilus
    zed-editor

    vial
    obsidian
    mangohud
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-vkcapture
        obs-vaapi
        obs-gstreamer
      ];
    })
    obs-studio-plugins.obs-vkcapture
    # nextcloud-client
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
