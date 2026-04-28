{
  config,
  lib,
  pkgs,
  ...
}:

let
  greeting = "turmoil accompanies every great change";
  sessionCommand =
    if config.desktop.environment == "gnome" then
      "gnome-session"
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
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --time \
              --asterisks \
              --user-menu \
              --greeting "${greeting}" \
              --theme "border=magenta;text=magenta;prompt=magenta;time=magenta;action=magenta;button=magenta;container=black;input=white" \
              --cmd ${lib.escapeShellArg sessionCommand} \
              --remember \
              --remember-session
          '';
          user = "greeter";
        };
      };
    };
  };
}
