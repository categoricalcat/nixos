{ lib, ... }:
{
  programs.alacritty = {
    enable = true;
    theme = "aura";

    settings = {
      window = {
        startup_mode = "Fullscreen";
        decorations = "Full";
        padding = {
          x = 10;
          y = 10;
        };
        dynamic_title = true;
        opacity = lib.mkDefault 0.85;
        blur = true;
      };

      font = {
        size = lib.mkForce 14.0;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      selection = {
        save_to_clipboard = true;
      };

      keyboard.bindings = [
        {
          key = "T";
          mods = "Control|Shift";
          action = "SpawnNewInstance";
        }
      ];
    };
  };
}
