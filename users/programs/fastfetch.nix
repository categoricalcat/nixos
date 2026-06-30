{ lib, ... }:
let
  c = import ../../modules/colors.nix { };
  keyModules = [
    {
      type = "os";
      key = "OS";
    }
    {
      type = "host";
      key = "Host";
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
      type = "packages";
      key = "Packages";
    }
    {
      type = "shell";
      key = "Shell";
    }
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
      type = "terminal";
      key = "Terminal";
    }
    {
      type = "display";
      key = "Display";
    }
    {
      type = "font";
      key = "Font";
    }
    {
      type = "icons";
      key = "Icons";
    }
    {
      type = "cpu";
      key = "CPU";
    }
    {
      type = "gpu";
      key = "GPU";
    }
    {
      type = "memory";
      key = "Memory";
    }
    {
      type = "swap";
      key = "Swap";
    }
    {
      type = "disk";
      key = "Disk";
    }
    {
      type = "localip";
      key = "Local IP";
    }
    {
      type = "battery";
      key = "Battery";
    }
    {
      type = "locale";
      key = "Locale";
    }
  ];

  themeColors = with c.base; [
    base08 # red
    base09 # peach
    base0A # yellow
    base0B # green
    base0C # teal
    base0D # blue
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
          "1" = "#${c.base.base0C}";
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
