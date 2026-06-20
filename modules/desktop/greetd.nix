{
  config,
  lib,
  pkgs,
  ...
}:

let
  sessionCommand =
    if config.desktop.environment == "gnome" then
      "GNOME"
    else if config.desktop.environment == "niri" then
      "niri-session"
    else
      config.desktop.environment;
in

{
  config = lib.mkIf (config.desktop.greeter == "tuigreet") {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          # Customized tuigreet command
          command = lib.concatStringsSep " " [
            "${pkgs.tuigreet}/bin/tuigreet"
            "--time"
            "--asterisks"
            "--user-menu"
            "--cmd ${lib.escapeShellArg sessionCommand}"
            "--greeting ${lib.escapeShellArg config.desktop.greeting}"
            "--theme ${lib.escapeShellArg "border=magenta;text=magenta;prompt=magenta;time=magenta;action=magenta;button=magenta;container=black;input=white"}"
            "--remember"
            "--remember-session"
          ];
          user = "greeter";
        };
      };
    };

    # Ensure tuigreet has the necessary cache directory permissions and runs smoothly
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal"; # Without this, errors will spam on screen
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      CacheDirectory = "tuigreet";
    };
  };
}
