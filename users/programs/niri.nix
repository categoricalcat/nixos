{
  lib,
  pkgs,
  config,
  options,
  inputs,
  ...
}:

let
  desktopShell = config.host.desktopShell;
  monitors = config.desktop.monitors;
  hdr = config.desktop.hdr;
  kdl = inputs.niri.lib.kdl;
  colors = import ../../modules/theme.nix;
  animRate = config.desktop.animationRate;
  mouse = config.desktop.mouse;
  keybinds = import ../../modules/desktop/keybinds { inherit lib; };

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

  parseTransform = t: {
    rotation =
      {
        normal = 0;
        "90" = 90;
        "180" = 180;
        "270" = 270;
        flipped = 0;
        "flipped-90" = 90;
        "flipped-180" = 180;
        "flipped-270" = 270;
      }
      .${t};
    flipped = lib.hasPrefix "flipped" t;
  };

  outputName = m: if m.connector != null then m.connector else m.name;

  typedOutputs = builtins.listToAttrs (
    map (m: {
      name = outputName m;
      value = {
        mode = parseMode m.mode;
        inherit (m) scale;
        transform = parseTransform m.transform;
        position = lib.optionalAttrs (m.position != null) {
          x = m.position.x;
          y = m.position.y;
        };
      }
      // lib.optionalAttrs (m ? vrr && m.vrr != null) {
        variable-refresh-rate = m.vrr;
      };
    }) monitors
  );

in
{
  imports = [
    inputs.niri.homeModules.config
    inputs.dms.homeModules.niri
    ./niri-dms.nix
  ];

  config = {
    xdg.enable = true;

    programs.niri = {
      package =
        if hdr then
          pkgs.callPackage ../../packages/niri-spicy.nix {
            niri-spicy = inputs.niri-spicy.packages.${pkgs.stdenv.hostPlatform.system}.niri;
            inherit (inputs) smithay-spicy;
          }
        else
          inputs.niri-unstable.packages.${pkgs.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ../../packages/niri-focus-delay.patch
            ];
          });
      settings = {
        prefer-no-csd = true;

        spawn-at-startup = [
          {
            argv = [
              "bash"
              "-c"
              "wl-paste --watch cliphist store &"
            ];
          }
          { argv = [ "niri-float-sticky" ]; }
        ];

        environment = {
          XDG_CURRENT_DESKTOP = "niri";
          QT_QPA_PLATFORM = "wayland";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          QT_QPA_PLATFORMTHEME = "qt6ct";
          QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
          TERMINAL = "kitty";
        };

        hotkey-overlay.skip-at-startup = true;

        screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

        overview.backdrop-color = "#${colors.base00}";

        animations = {
          enable = animRate > 0.0;
          slowdown = if animRate > 0.0 then animRate else 1.0;
        };

        input = {
          mouse = {
            accel-profile = mouse.accelProfile;
            accel-speed = mouse.accelSpeed;
            scroll-factor = mouse.scrollFactor;
            natural-scroll = mouse.naturalScrolling;
            left-handed = mouse.leftHanded;
            middle-emulation = mouse.middleEmulation;
          };
          trackball = {
            accel-profile = mouse.accelProfile;
            accel-speed = mouse.accelSpeed;
            natural-scroll = mouse.naturalScrolling;
            left-handed = mouse.leftHanded;
            middle-emulation = mouse.middleEmulation;
          };
          touchpad = {
            tap = true;
            natural-scroll = true;
            scroll-factor = mouse.scrollFactor;
            left-handed = mouse.leftHanded;
          };
          warp-mouse-to-focus.enable = true;
          focus-follows-mouse = {
            enable = true;
          };
        };

        outputs = typedOutputs;

        layout = {
          gaps = 6;
          background-color = "transparent";
          center-focused-column = "never";
          always-center-single-column = true;
          struts = {
            left = 16;
            right = 32;
          };
          preset-column-widths = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
            { proportion = 1.0; }
          ];
          default-column-width = {
            proportion = 0.5;
          };
          focus-ring = {
            enable = true;
            width = 0.5;
            active = {
              color = "#${colors.base0D}";
            };
            inactive = {
              color = "#${colors.base03}";
            };
          };
          border = {
            enable = false;
            width = 1;
            active = {
              color = "#${colors.base0D}";
            };
            inactive = {
              color = "#${colors.base03}";
            };
          };
          shadow = {
            enable = true;
            softness = 30;
            spread = 5;
            offset = {
              x = 0;
              y = 5;
            };
            color = "#${colors.base00}";
          };
        };

        window-rules = [
          {
            matches = [ { title = "(?i)picture-in-picture"; } ];
            open-floating = true;
          }
          {
            geometry-corner-radius = {
              top-left = 6.0;
              top-right = 6.0;
              bottom-left = 6.0;
              bottom-right = 6.0;
            };
            clip-to-geometry = true;
            draw-border-with-background = false;
          }
        ];

        binds = keybinds.getNiriBinds {
          inherit desktopShell hdr;
          terminalCommand = "kitty";
          emojiCommand = "smile";
        };
      };

      config =
        let
          recentWindowsNode =
            kdl.node "recent-windows"
              [ ]
              [
                (kdl.node "binds"
                  [ ]
                  [
                    (kdl.node "Mod+Tab" [ ] [ (kdl.node "next-window" [ ] [ ]) ])
                    (kdl.node "Mod+Shift+Tab" [ ] [ (kdl.node "previous-window" [ ] [ ]) ])
                    (kdl.node "Mod+grave" [ ] [ (kdl.node "next-window" [ { filter = "app-id"; } ] [ ]) ])
                    (kdl.node "Mod+Shift+grave" [ ] [ (kdl.node "previous-window" [ { filter = "app-id"; } ] [ ]) ])
                  ]
                )
              ];
          baseNodes =
            if hdr then
              let
                hdrByOutput = builtins.listToAttrs (
                  map (m: {
                    name = outputName m;
                    value = kdl.node "hdr" [ { mode = m.hdrMode; } ] (
                      lib.optional (m.hdrReferenceLuminance != null) (
                        kdl.leaf "reference-luminance" m.hdrReferenceLuminance
                      )
                      ++ lib.optional (m.hdrMaxLum != null && m.hdrMaxLum >= 1) (kdl.leaf "peak-luminance" m.hdrMaxLum)
                    );
                  }) (lib.filter (m: m.hdr) monitors)
                );
              in
              map (
                node:
                let
                  args = node.arguments or [ ];
                  key = if args == [ ] then null else builtins.head args;
                in
                if node.name or null == "output" && key != null && hdrByOutput ? ${key} then
                  node
                  // {
                    children = node.children ++ [ hdrByOutput.${key} ];
                  }
                else
                  node
              ) (lib.remove null (lib.flatten options.programs.niri.config.default))
            else
              lib.remove null (lib.flatten options.programs.niri.config.default);
        in
        baseNodes ++ [ recentWindowsNode ];
    };

    xdg.configFile = lib.mkIf (desktopShell == "dms") {
      "niri/dms/binds.kdl".text = keybinds.generateDmsBindsKdl {
        inherit desktopShell hdr;
        terminalCommand = "kitty";
        emojiCommand = "smile";
      };
    };
  };
}
