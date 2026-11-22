{ config, lib, ... }:

{
  options.host = {
    desktopEnvironment = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "gnome"
          "niri"
          "mango"
        ]
      );
      default = null;
      description = "Desktop environment. null means headless.";
    };

    desktopShell = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "dms"
          "noctalia"
          "none"
        ]
      );
      default =
        if
          lib.elem config.host.desktopEnvironment [
            "niri"
            "mango"
          ]
        then
          "dms"
        else
          null;
      description = "Desktop shell running on top of the compositor.";
    };

    barScreenPreferences = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "all" ];
      example = [ "DP-1" ];
      description = "Outputs the desktop shell bar is shown on, or \"all\" for every output.";
    };

    vr = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Host can run VR (SteamVR/OpenXR)";
    };

    workd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable workd isolated user environment on this host";
    };
  };
}
