{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    floorp-bin # the good

    vscode-fhs
    code-cursor-fhs
    antigravity
    onlyoffice-desktopeditors
    discord
    # vesktop # uses insecure pnpm_10_29_2 at build time

    qbz
    dbeaver-bin
    github-desktop

    wl-clipboard

    # (bitwarden-desktop.override { electron_39 = electron; })
    prismlauncher
    gimp
    nautilus
    zed-editor

    vial
    obsidian
    mangohud
    multiviewer-for-f1
    jellyfin-media-player
    scrcpy
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
