{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  dmsSettings = builtins.fromJSON (builtins.readFile ./dms/settings.json);
  dmsSession = builtins.fromJSON (builtins.readFile ./dms/session.json);
  dmsBar = builtins.elemAt dmsSettings.barConfigs 0;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPackage;

    settings = {
      # ── Bar ──
      bar.main = {
        position =
          if dmsBar.position == 0 then
            "top"
          else if dmsBar.position == 1 then
            "bottom"
          else if dmsBar.position == 2 then
            "left"
          else
            "right";
        scale = dmsBar.fontScale;
        capsule = true;
        capsule_opacity = dmsBar.widgetTransparency;

        start = [
          "launcher"
          "workspaces"
          "active_window"
        ];
        center = [
          "media"
          "clock"
        ];
        end = [
          "sysmon"
          "battery"
          "spacer"
          "tray"
          "notifications"
          "network"
          "bluetooth"
          "brightness"
          "control-center"
        ];
      };

      # ── Shell / UI / General ──
      shell = {
        ui_scale = dmsSettings.fontScale;
        font_family = themeAssets.fonts.sansSerif.name;
        time_format = if dmsSettings.use24HourClock then "{:%H:%M}" else "{:%I:%M %p}";
      };

      shell.animation = {
        enabled = dmsSettings.animationSpeed != 0;
        speed = if dmsSettings.animationSpeed == 0 then 1.5 else 1.0;
      };

      shell.shadow = {
        alpha = if dmsBar.shadowOpacity > 0 then (dmsBar.shadowOpacity / 10.0) else 0.55;
      };

      backdrop = {
        enabled = true;
      };

      # ── Color Schemes ──
      theme = {
        mode = if dmsSession.isLightMode then "light" else "dark";
        source = "wallpaper";
        wallpaper_scheme = lib.removePrefix "scheme-" dmsSettings.matugenScheme;
      };

      # ── Location & Weather ──
      weather = {
        enabled = dmsSettings.weatherEnabled;
        unit = if dmsSettings.useFahrenheit then "fahrenheit" else "celsius";
      };

      location = {
        auto_locate = dmsSettings.useAutoLocation;
      };

      # ── Notifications & OSD ──
      notification = {
        enable_daemon = true;
      };

      osd = {
        position = "top_right";
      };
    };
  };

  # Make Noctalia settings mutable at runtime (same pattern as DMS)
  home.activation.makeNoctaliaMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for file in config.toml; do
      target="$HOME/.config/noctalia/$file"
      if [ -L "$target" ]; then
        store_path=$(readlink -f "$target")
        rm -f "$target"
        cp "$store_path" "$target"
        chmod u+w "$target"
      fi
    done
  '';

  xdg.configFile."autostart/noctalia-shell.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Noctalia Shell
    Comment=Wayland desktop shell
    Exec=env QT_IM_MODULE= ${lib.getExe noctaliaPackage}
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
