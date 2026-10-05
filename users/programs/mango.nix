{
  lib,
  config,
  pkgs,
  ...
}:

let
  keybinds = import ../../modules/desktop/keybinds.nix { inherit lib; };
  keyboard = import ../../modules/keyboard/profiles.nix;
  keyboardProfiles = map (name: keyboard.profiles.${name}) (keyboard.order config.desktop.keyboard);
  desktopShell = config.host.desktopShell;
  monitors = config.desktop.monitors;
  colors = import ../../modules/theme.nix;
  dmsSettings = builtins.fromJSON (builtins.readFile ./dms/settings.json);
  animRate = config.desktop.animationRate;
  scale = ms: if animRate <= 0.0 then 0 else lib.trivial.max 1 (builtins.floor (ms * animRate));
  mouse = config.desktop.mouse;
  accelProfileToMango =
    {
      "flat" = 1;
      "adaptive" = 2;
    }
    .${mouse.accelProfile};

  parseMode =
    mode:
    if mode == null then
      null
    else
      let
        m = builtins.match "([0-9]+)x([0-9]+)(@([0-9.]+))?" mode;
      in
      if m == null then
        null
      else
        {
          width = builtins.fromJSON (builtins.elemAt m 0);
          height = builtins.fromJSON (builtins.elemAt m 1);
          refresh =
            let
              r = builtins.elemAt m 3;
            in
            if r == null then null else (builtins.fromJSON r) * 1.0;
        };

  transformToRr =
    t:
    {
      normal = 0;
      "90" = 1;
      "180" = 2;
      "270" = 3;
      flipped = 4;
      "flipped-90" = 5;
      "flipped-180" = 6;
      "flipped-270" = 7;
    }
    .${t};

  formatMonitorRule =
    m:
    let
      targetName = if m.connector != null then m.connector else m.name;
      parsedMode = parseMode m.mode;
      parts = [
        "name:^${targetName}$"
      ]
      ++ lib.optionals (parsedMode != null) [
        "width:${toString parsedMode.width}"
        "height:${toString parsedMode.height}"
      ]
      ++ lib.optionals (parsedMode != null && parsedMode.refresh != null) [
        "refresh:${toString parsedMode.refresh}"
      ]
      ++ lib.optionals (m.position != null) [
        "x:${toString m.position.x}"
        "y:${toString m.position.y}"
      ]
      ++ [
        "scale:${toString m.scale}"
        "rr:${toString (transformToRr m.transform)}"
        "vrr:${if m.vrr then "1" else "0"}"
        "hdr:${if m.hdr then "1" else "0"}"
      ]
      ++ lib.optionals (m.hdrMinLum != null) [
        "hdr_min_lum:${toString m.hdrMinLum}"
      ]
      ++ lib.optionals (m.hdrMaxLum != null) [
        "hdr_max_lum:${toString m.hdrMaxLum}"
      ]
      ++ lib.optionals (m.hdrMaxAvgLum != null) [
        "hdr_max_avg_lum:${toString m.hdrMaxAvgLum}"
      ]
      ++ lib.optionals m.hdrForce [
        "hdr_force:1"
      ];
    in
    lib.concatStringsSep "," parts;
in
{
  config = lib.mkIf (config.host.desktopEnvironment == "mango") {
    wayland.windowManager.mango = {
      enable = true;
      systemd.enable = true;
      autostart_sh = "";

      bottomPrefixes = [
        "source"
        "source_optional"
      ];

      settings = {
        exec_once = [
          "~/.config/mango/autostart.sh"
        ];
        env = [
          "WLR_RENDERER,vulkan"
        ];
        hdr_depth = 2;
        xkb_rules_layout = lib.concatMapStringsSep "," (profile: profile.layout) keyboardProfiles;
        xkb_rules_variant = lib.concatMapStringsSep "," (profile: profile.variant) keyboardProfiles;

        # Window & root colors from theme.yaml (yimoka base16)
        root_color = "0x${colors.base00}ff";
        border_color = "0x${colors.base03}ff";
        focus_color = "0x${colors.base0D}ff";
        urgent_color = "0x${colors.base08}ff";
        drop_color = "0x${colors.base0D}55";
        split_color = "0x${colors.base09}ff";

        # Window state-specific colors
        maximized_screen_color = "0x${colors.base0B}ff";
        scratchpad_color = "0x${colors.base0C}ff";
        global_color = "0x${colors.base0E}ff";
        overlay_color = "0x${colors.base0D}ff";

        # Overview jump mode label colors & radius
        jump_label_decorate_fg_color = "0x${colors.base05}ff";
        jump_label_decorate_bg_color = "0x${colors.base01}ff";
        jump_label_decorate_focus_fg_color = "0x${colors.base00}ff";
        jump_label_decorate_focus_bg_color = "0x${colors.base0E}ff";
        jump_label_decorate_border_color = "0x${colors.base0D}ff";
        jump_label_decorate_corner_radius = dmsSettings.cornerRadius or 8;

        # Tab bar (monocle layout) colors & radius
        group_bar_decorate_fg_color = "0x${colors.base05}ff";
        group_bar_decorate_bg_color = "0x${colors.base01}ff";
        group_bar_decorate_focus_fg_color = "0x${colors.base00}ff";
        group_bar_decorate_focus_bg_color = "0x${colors.base0E}ff";
        group_bar_decorate_border_color = "0x${colors.base0D}ff";
        group_bar_decorate_corner_radius = dmsSettings.cornerRadius or 8;

        # Layout borders and gaps
        border_px = 2;
        gap_inner_horizontal = 4;
        gap_inner_vertical = 4;
        gap_outer_horizontal = 4;
        gap_outer_vertical = 4;

        # Disable mouse auto-focus (click-to-focus only)
        sloppy_focus = 0;
        edge_scroller_pointer_focus = 0;

        # Global mouse settings from desktop.mouse
        mouse_accel_profile = accelProfileToMango;
        mouse_accel_speed = mouse.accelSpeed;
        axis_scroll_factor = mouse.scrollFactor;
        trackpad_scroll_factor = mouse.scrollFactor;
        mouse_natural_scrolling = if mouse.naturalScrolling then 1 else 0;
        mouse_middle_button_emulation = if mouse.middleEmulation then 1 else 0;
        mouse_left_handed = if mouse.leftHanded then 1 else 0;
        trackpad_left_handed = if mouse.leftHanded then 1 else 0;
        trackpad_middle_button_emulation = if mouse.middleEmulation then 1 else 0;

        tap_to_click = 1;
        trackpad_natural_scrolling = 1;
        swipe_min_threshold = 15;

        # Smooth window and layer animations (no bottom slide)
        animations = if animRate <= 0.0 then 0 else 1;
        layer_animations = if animRate <= 0.0 then 0 else 1;
        animation_type_open = "zoom";
        animation_type_close = "zoom";
        layer_animation_type_open = "fade";
        layer_animation_type_close = "fade";
        zoom_initial_ratio = 0.8;
        zoom_end_ratio = 0.85;
        animation_fade_in = if animRate <= 0.0 then 0 else 1;
        animation_fade_out = if animRate <= 0.0 then 0 else 1;
        fade_in_begin_opacity = 0.3;
        fade_out_begin_opacity = 0.3;
        animation_duration_open = scale 200;
        animation_duration_close = scale 200;
        animation_duration_move = scale 250;
        animation_duration_tag = scale 200;
        tag_animation_direction = 1;

        monitor_rule = map formatMonitorRule monitors;

        tag_rule = [
          "id:*,layout_name:scroller"
        ];

        window_rule = [
          "app_id:^com.danklinux.dms$,is_floating:1"
        ];

        scroller_structs = 20;
        scroller_default_proportion = 0.666667;
        scroller_prefer_overspread = 1;
        scroller_proportion_preset = "0.333333,0.5,0.666667,1.0";

        source_optional = [
          "~/.config/mango/noctalia.conf"
          "~/.config/mango/dms/cursor.conf"
          "~/.config/mango/dms/outputs.conf"
        ]
        ++ (
          if desktopShell == "dms" then
            [
              "~/.config/mango/dms/binds.conf"
            ]
          else
            [
              "~/.config/mango/binds.conf"
            ]
        );
      };
    };

    wayland.systemd.target = "mango-session.target";

    programs.dank-material-shell.systemd.target = lib.mkIf (
      desktopShell == "dms"
    ) "mango-session.target";

    xdg.configFile =
      (
        if desktopShell == "dms" then
          {
            "mango/dms/binds.conf".text = keybinds.generateMangoConfig {
              terminalCommand = "kitty";
              inherit desktopShell;
            };
          }
        else
          {
            "mango/binds.conf".text = keybinds.generateMangoConfig {
              terminalCommand = "kitty";
              inherit desktopShell;
            };
          }
      )
      // {
        "mango/autostart.sh" = {
          executable = true;
          text = ''
            ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE NIXOS_OZONE_WL XCURSOR_THEME XCURSOR_SIZE
            systemctl --user reset-failed
            systemctl --user start mango-session.target
          '';
        };
      };
  };
}
