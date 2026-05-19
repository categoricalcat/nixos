{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    package = noctaliaPackage;

    settings = {
      # ── Bar (mapped from DMS barConfigs[0]) ──
      bar = {
        position = "top"; # DMS position = 0 → top
        barType = "simple"; # DMS uses no floating/framed bar
        density = "default";
        showCapsule = true;
        fontScale = 1.0; # DMS barConfigs[0].fontScale = 1
        outerCorners = true;
        # backgroundOpacity, capsuleOpacity → provided by Stylix (opacity.desktop = 1.0)

        # Widget layout mapped from DMS barConfigs[0].leftWidgets/centerWidgets/rightWidgets
        widgets = {
          left = [
            { id = "Launcher"; } # DMS: launcherButton
            { id = "Workspace"; } # DMS: workspaceSwitcher
            { id = "ActiveWindow"; } # DMS: focusedWindow
          ];
          center = [
            { id = "MediaMini"; } # DMS: music
            { id = "Clock"; } # DMS: clock
          ];
          right = [
            { id = "SystemMonitor"; } # DMS: cpuTemp + cpuUsage + memUsage (combined)
            { id = "Battery"; } # DMS: battery
            { id = "Tray"; } # DMS: systemTray
            { id = "NotificationHistory"; } # DMS: notificationButton
            { id = "ControlCenter"; } # DMS: controlCenterButton
          ];
        };
      };

      # ── General ──
      general = {
        animationSpeed = 1.5; # DMS animationSpeed=0 → snappy preset
        enableShadows = true;
        enableBlurBehind = true;
      };

      # ── UI ──
      # Fonts match the shared theme assets used by DMS.
      ui = {
        fontDefault = themeAssets.fonts.sansSerif.name;
        fontFixed = themeAssets.fonts.monospace.name;
        fontDefaultScale = 1.0; # DMS fontScale = 1
        panelBackgroundOpacity = lib.mkForce 0.93; # DMS widgetTransparency=0.48 → semi-transparent panels
      };

      # ── Location / Weather ──
      location = {
        weatherEnabled = true; # DMS showWeather = true
        useFahrenheit = false; # DMS useFahrenheit = false
        use12hourFormat = false; # DMS use24HourClock = true
        autoLocate = true; # DMS useAutoLocation = true
      };

      # ── Color Schemes (DMS uses Matugen scheme-vibrant → Noctalia built-in Material You) ──
      colorSchemes = {
        darkMode = true; # DMS session isLightMode = false
        useWallpaperColors = true; # DMS uses Matugen dynamic theming
        generationMethod = "vibrant"; # DMS matugenScheme = "scheme-vibrant"
        syncGsettings = true;
      };

      # ── Dock ──
      dock = {
        enabled = false; # DMS showDock = false
        # backgroundOpacity → provided by Stylix (opacity.desktop = 1.0)
      };

      # ── App Launcher ──
      appLauncher = {
        viewMode = "list"; # DMS appLauncherViewMode = "list"
      };

      # ── Notifications ──
      # backgroundOpacity → provided by Stylix (opacity.popups = 1.0)
      notifications = {
        enabled = true;
        location = "top_right";
        sounds = {
          enabled = true; # DMS soundsEnabled = true
        };
      };

      # ── OSD ──
      # backgroundOpacity → provided by Stylix (opacity.popups = 1.0)
      osd = {
        enabled = true;
      };
    };
  };

  # Make Noctalia settings mutable at runtime (same pattern as DMS)
  home.activation.makeNoctaliaMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for file in settings.json colors.json user-templates.toml; do
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
    Exec=${lib.getExe noctaliaPackage}
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
