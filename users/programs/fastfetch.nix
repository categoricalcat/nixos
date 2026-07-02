{ lib, ... }:
let
  c = import ../../modules/colors.nix { };
  keyModules = [
    # ── System ──
    {
      type = "os";
      key = "OS";
    }
    {
      type = "host";
      key = "Host";
    }
    {
      type = "command";
      key = "Age";
      text = "birth=$(stat -c %W /); now=$(date +%s); echo $(( (now - birth) / 86400 )) days";
    }
    {
      type = "kernel";
      key = "Kernel";
    }
    {
      type = "uptime";
      key = "Uptime";
    }
    {
      type = "command";
      key = "Time";
      text = "date +'%A, %-d %B %Y %H:%M:%S'";
    }
    {
      type = "processes";
      key = "Processes";
    }
    {
      type = "packages";
      key = "Packages";
    }

    # ── Shell & Terminal ──
    {
      type = "shell";
      key = "Shell";
    }
    {
      type = "terminal";
      key = "Terminal";
    }

    # ── Desktop ──
    {
      type = "de";
      key = "DE";
    }
    {
      type = "wm";
      key = "WM";
    }
    {
      type = "lm";
      key = "LM";
    }
    {
      type = "theme";
      key = "Theme";
    }
    {
      type = "wmtheme";
      key = "WM Theme";
    }
    {
      type = "cursor";
      key = "Cursor";
    }
    {
      type = "font";
      key = "Font";
    }
    {
      type = "icons";
      key = "Icons";
    }

    # ── Hardware ──
    {
      type = "cpu";
      key = "CPU";
    }
    {
      type = "gpu";
      key = "GPU";
    }
    {
      type = "vulkan";
      key = "Vulkan";
    }
    {
      type = "memory";
      key = "Memory";
    }
    {
      type = "physicalmemory";
      key = "RAM";
    }
    {
      type = "swap";
      key = "Swap";
    }
    {
      type = "disk";
      key = "Disk";
    }

    # ── Peripherals ──
    {
      type = "display";
      key = "Display";
    }
    {
      type = "brightness";
      key = "Brightness";
    }
    {
      type = "sound";
      key = "Sound";
    }
    {
      type = "gamepad";
      key = "Gamepad";
    }
    {
      type = "poweradapter";
      key = "Power";
    }
    {
      type = "battery";
      key = "Battery";
    }
    {
      type = "bluetoothradio";
      key = "BT Radio";
    }

    # ── Misc ──
    {
      type = "locale";
      key = "Locale";
    }
    {
      type = "player";
      key = "Player";
    }
  ];

  themeColors = with c.base; [
    base08 # red
    base09 # peach
    base0A # yellow
    base0B # green
    base0D # teal
    base0C # blue
    base0E # mauve
    base0F # pink
  ];

  smoothThemeGradient = c.makeGradient themeColors (builtins.length keyModules);
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "data";
        source = ''
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣠⣤⣤⣀⣠⣀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⢄⣰⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣦⣤⡠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⣂⣵⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⣪⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡝⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⢀⢰⠢⣺⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⡀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠐⡐⢔⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢫⠃⠀⣇⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣡⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⢀⠊⠀⣹⣿⣿⣿⣿⣿⣏⣀⣿⣿⣿⣿⣿⣿⣿⣿⠟⡡⠃⠀⠀⡿⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠨⠀⣜⣿⣿⣿⡟⢿⠗⠠⢄⢿⣏⣿⣿⠹⣿⡟⠡⠮⠤⢄⣀⣀⡛⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠘⠟⣹⣿⣿⣷⠞⠒⢷⣶⣝⡍⠈⠻⠀⢉⡣⠴⠒⠒⠒⠀⠄⠘⣉⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠠⠘⢼⢿⣿⡇⠅⠀⠈⠻⠿⢷⠒⠒⢤⠋⠀⠀⠐⠚⠛⣶⣶⣶⣬⣆⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠰⡀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⡀⡿⢿⠀⠀⠀⠀⠀⡠⠋⠀⠀⠸⡦⠀⠀⠀⠀⠀⠙⠛⠿⠟⡹⠛⠒⠮⠭⣿⣿⣿⡿⠿⣿⣿⣿⣿⡿⠄⢁⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⢄⡿⠁⣸⠉⠐⠒⠒⠀⠐⠀⠀⠀⠀⠙⢄⠀⠀⠀⠀⠀⠀⠀⡰⠃⠀⠀⠀⠈⠀⢛⠁⠀⠀⠸⣿⣿⣿⠓⠀⠈⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠈⡌⡇⠀⠻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠑⠒⠂⠐⠒⠉⠀⠀⠀⠀⠀⠀⠀⢈⠁⠀⠀⢸⣿⣿⣣⡀⢀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠁⠃⠃⢀⢃⢱⡀⠀⠀⠀⠀⠤⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⠂⠀⢀⣠⣴⣿⣿⣿⡏⣏⠌⡐⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠈⠂⢊⡀⠀⠢⠑⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠴⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣇⢻⠨⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⢀⠁⠀⠀⠀⠈⢢⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡤⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠉⡜⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠨⠘⡀⠀⠀⠀⠀⠑⢄⣀⣀⣀⣀⣠⣤⣤⣴⣶⣾⠿⠛⠁⠀⠀⠀⠀⣟⠿⣻⠿⣿⡿⠿⠟⡨⡁⠐⠀⠠⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠐⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⡿⠟⠋⠁⠀⠀⠀⠀⠀⠀⢀⣿⣿⡿⡑⠄⢂⠩⠉⢀⠀⠄⠈⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠂⠀⠀⠀⠀⠀⠀⣠⣼⣆⠀⠀⠀⠀⠀⢀⣀⣤⣶⣾⣿⣿⣿⡇⠈⠀⠸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⣿⣿⣿⣤⣤⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣴⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀
          ⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦'';
        padding.right = 0;
        color = {
          "1" = "#${c.base.base0D}";
        };
      };
      display = {
        separator = " ➜ ";
        color = {
          keys = c.ansiFg c.base.base0F; # Pink (base0F) as fallback
          title = c.ansiFg c.base.base0E; # Mocha Mauve (base0E)
        };
      };
      modules = [
        "title"
        "separator"
      ]
      ++ (lib.imap0 (
        i: m:
        m
        // {
          keyColor = builtins.elemAt smoothThemeGradient i;
        }
      ) keyModules)
      ++ [
        "break"
        "colors"
      ];
    };
  };
}
