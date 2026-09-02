{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.dank-greeter.nixosModules.default
  ];

  config = lib.mkMerge [
    (lib.mkIf (config.desktop.greeter == "tuigreet") {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            # Customized tuigreet command
            command =
              let
                sessions = "${config.services.displayManager.sessionData.desktops}/share";
                # tuigreet only takes ANSI names, not hex. Stylix console.colors
                # maps yimoka teal (base0D) to blue/lightblue, not cyan (base0C indigo).
                teal = "blue";
                tealBright = "lightblue";
                themeString = lib.concatStringsSep ";" [
                  "border=${teal}"
                  "text=white"
                  "prompt=${teal}"
                  "time=${teal}"
                  "action=${teal}"
                  "button=${tealBright}"
                  "container=black"
                  "input=${teal}"
                  "greet=${teal}"
                  "title=${teal}"
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
    })

    (lib.mkIf (config.desktop.greeter == "dms") {
      programs.dms-greeter = {
        enable = true;
        compositor.name =
          if config.desktop.environment == "mango" then
            "mango"
          else if config.desktop.environment == "niri" then
            "niri"
          else
            "mango";
        configHome = "/home/yi";
      };
    })
  ];
}
