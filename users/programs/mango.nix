{
  lib,
  config,
  inputs,
  ...
}:

let
  desktopShell = config.host.desktopShell;
  monitors = config.desktop.monitors;

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

  dmsEmbedded = "${inputs.dms.outPath}/core/internal/config/embedded";
in
{
  config = lib.mkIf (config.host.desktopEnvironment == "mango") {
    wayland.windowManager.mango = {
      enable = true;
      systemd.enable = true;
      autostart_sh = ":";

      bottomPrefixes = [
        "source"
        "source-optional"
      ];

      settings = {
        env = [
          "WLR_RENDERER,vulkan"
        ];
        hdr_depth = 2;

        # Disable mouse auto-focus (click-to-focus only)
        sloppyfocus = 0;
        edge_scroller_pointer_focus = 0;

        # Smooth window and layer animations (no bottom slide)
        animations = 1;
        layer_animations = 1;
        animation_type_open = "zoom";
        animation_type_close = "zoom";
        layer_animation_type_open = "fade";
        layer_animation_type_close = "fade";
        zoom_initial_ratio = 0.8;
        zoom_end_ratio = 0.85;
        animation_fade_in = 1;
        animation_fade_out = 1;
        fadein_begin_opacity = 0.3;
        fadeout_begin_opacity = 0.3;
        animation_duration_open = 200;
        animation_duration_close = 200;
        animation_duration_move = 250;
        animation_duration_tag = 200;
        tag_animation_direction = 1;

        monitorrule = map formatMonitorRule monitors;

        tagrule = [
          "id:*,layout_name:scroller"
        ];

        bindr = [
          "Super,Super_L,toggleoverview"
          "Super,Super_R,toggleoverview"
        ];

        scroller_structs = 20;
        scroller_default_proportion = 0.9;
        scroller_prefer_overspread = 1;
        scroller_proportion_preset = "0.5,0.8,1.0";

        source-optional = [
          "~/.config/mango/dms/binds.conf"
          "~/.config/mango/dms/colors.conf"
          "~/.config/mango/dms/layout.conf"
          "~/.config/mango/dms/cursor.conf"
          "~/.config/mango/dms/outputs.conf"
          "~/.config/mango/dms/windowrules.conf"
        ];
      };
    };

    programs.dank-material-shell.systemd.target = lib.mkIf (
      desktopShell == "dms"
    ) "mango-session.target";

    xdg.configFile = lib.mkIf (desktopShell == "dms") {
      "mango/dms/binds.conf".text = builtins.replaceStrings [ "{{TERMINAL_COMMAND}}" ] [ "kitty" ] (
        builtins.readFile "${dmsEmbedded}/mango-binds.conf"
      );
    };
  };
}
