{
  desktopEnvironment ? null,
  keyboardProfile ? "us-intl",
  lib,
  pkgs,
  ...
}:

let
  keyboardProfiles = {
    us-intl = {
      layout = "us";
      variant = "intl";
      fcitxLayout = "us-intl";
    };
    br-thinkpad = {
      layout = "br";
      variant = "thinkpad";
      fcitxLayout = "br-thinkpad";
    };
  };

  kb = keyboardProfiles.${keyboardProfile};
  gnomeSourceId = if kb.variant != "" then "${kb.layout}+${kb.variant}" else kb.layout;
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5.waylandFrontend = true;

    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
    ];

    fcitx5.settings = {
      globalOptions."Hotkey/TriggerKeys" = {
        "0" = "Control+Shift+space";
      };

      globalOptions.Hotkey = {
        EnumerateForwardKeys = "";
        EnumerateBackwardKeys = "";
        EnumerateGroupForwardKeys = "";
        EnumerateGroupBackwardKeys = "";
        EnumerateSkipFirst = false;
      };

      globalOptions.Behavior = {
        WaylandIMModuleWarning = "False";
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
        "Groups/0/Items/0" = {
          Name = "keyboard-${kb.fcitxLayout}";
          Layout = kb.fcitxLayout;
        };
        "Groups/0/Items/1" = {
          Name = "keyboard-br";
          Layout = kb.fcitxLayout;
        };
        "Groups/0/Items/2" = {
          Name = "pinyin";
          Layout = "";
        };
        GroupOrder."0" = "Default";
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
}
