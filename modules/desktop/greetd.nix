{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.desktop.greeter == "tuigreet") {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          # Customized tuigreet command
          command =
            let
              sessions = "${config.services.displayManager.sessionData.desktops}/share";
              themeString = lib.concatStringsSep ";" [
                "border=lightmagenta"
                "text=white"
                "prompt=lightcyan"
                "time=lightblue"
                "action=yellow"
                "button=lightyellow"
                "container=black"
                "input=lightblue"
                "greet=lightblue"
                "title=lightblue"
              ];
            in
            lib.concatStringsSep " " [
              "${pkgs.tuigreet}/bin/tuigreet"
              "--time"
              "--asterisks"
              "--user-menu"
              "--sessions ${sessions}/wayland-sessions"
              "--xsessions ${sessions}/xsessions"
              "--greeting ${lib.escapeShellArg config.desktop.greeting}"
              "--theme ${lib.escapeShellArg themeString}"
              "--remember"
              "--remember-session"
              "--container-padding 2"
              "--window-padding 1"
              "--power-shutdown 'systemctl poweroff'"
              "--power-reboot 'systemctl reboot'"
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
