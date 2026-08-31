{
  lib,
  pkgs,
  config,
  ...
}:

let
  inherit (config.host) desktopEnvironment;
  keyboardProfile = config.desktop.keyboard;
  keyboard = import ./profiles.nix;
  profileOrder = keyboard.order keyboardProfile;
  kb = keyboard.profiles.${keyboardProfile};
  keyboardItems = builtins.listToAttrs (
    lib.imap0 (
      index: profileName:
      let
        profile = keyboard.profiles.${profileName};
      in
      lib.nameValuePair "Groups/0/Items/${toString index}" {
        Name = "keyboard-${profile.fcitxLayout}";
        Layout = profile.fcitxLayout;
      }
    ) profileOrder
  );
  pinyinIndex = toString (builtins.length profileOrder);
  gnomeSourceId = if kb.variant != "" then "${kb.layout}+${kb.variant}" else kb.layout;
in
{
  config = lib.mkIf (config.host.desktopEnvironment != null) {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5 = {
        waylandFrontend = true;

        addons = with pkgs; [
          qt6Packages.fcitx5-chinese-addons
          fcitx5-gtk
        ];

        settings = {
          globalOptions = {
            "Hotkey/EnumerateForwardKeys" = {
              "0" = "Control+Shift+space";
            };
            "Hotkey/EnumerateBackwardKeys" = {
              "0" = "Control+Alt+Shift+space";
            };

            Hotkey = {
              EnumerateSkipFirst = false;
            };

            Behavior = {
              WaylandIMModuleWarning = "False";
            };
          };

          addons = {
            pinyin.globalSection.CloudPinyinEnabled = "True";
          };

          inputMethod = {
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = kb.fcitxLayout;
              DefaultIM = "keyboard-${kb.fcitxLayout}";
            };
            "Groups/0/Items/${pinyinIndex}" = {
              Name = "pinyin";
              Layout = "";
            };
            GroupOrder."0" = "Default";
          }
          // keyboardItems;
        };
      };
    };

    dconf = lib.mkIf (desktopEnvironment == "gnome") {
      enable = true;
      settings = {
        "org/gnome/desktop/input-sources".sources = [
          (lib.hm.gvariant.mkTuple [
            "xkb"
            gnomeSourceId
          ])
        ];

        "org/gnome/settings-daemon/plugins/xsettings" = {
          overrides = lib.hm.gvariant.mkArray "{sv}" [
            (lib.hm.gvariant.mkDictionaryEntry [
              "Gtk/IMModule"
              (lib.hm.gvariant.mkVariant "fcitx")
            ])
          ];
        };
      };
    };
  };
}
