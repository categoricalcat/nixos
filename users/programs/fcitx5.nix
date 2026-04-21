{ desktopEnvironment, ... }:

let
  config = ''
    [Hotkey]
    TriggerKeys=Control+Shift+space
    EnumerateForwardKeys=
    EnumerateBackwardKeys=
    EnumerateGroupForwardKeys=
    EnumerateGroupBackwardKeys=
    EnumerateSkipFirst=False
  '';

  profile =
    if desktopEnvironment == "gnome" then
      ''
        [Groups/0]
        Name=Default
        Default Layout=us-intl
        DefaultIM=keyboard-us-intl

        [Groups/0/Items/0]
        Name=keyboard-us-intl
        Layout=

        [Groups/0/Items/1]
        Name=pinyin
        Layout=

        [GroupOrder]
        0=Default
      ''
    else
      ''
        [Groups/0]
        Name=Default
        Default Layout=br
        DefaultIM=keyboard-br

        [Groups/0/Items/0]
        Name=keyboard-br
        Layout=

        [Groups/0/Items/1]
        Name=pinyin
        Layout=

        [GroupOrder]
        0=Default
      '';
in
{
  xdg.configFile = {
    "fcitx5/config".text = config;
    "fcitx5/profile".text = profile;
  };
}
