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
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --time \
              --asterisks \
              --user-menu \
              --greeting "turmoil accompanies every great change" \
              --theme "border=magenta;text=magenta;prompt=magenta;time=magenta;action=magenta;button=magenta;container=black;input=white" \
              --cmd "niri-session" \
              --remember \
              --remember-session
          '';
          user = "greeter";
        };
      };
    };
  };
}
