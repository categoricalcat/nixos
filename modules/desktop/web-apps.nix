{ pkgs, ... }:

let
  # Import string manipulation library
  inherit (pkgs.lib.strings) toLower;

  mkWebApp =
    {
      name,
      url,
      # Automatically convert "YouTube" -> "youtube", which matches the icon theme file
      icon ? toLower name,
      categories ? [
        "Network"
        "WebBrowser"
      ],
    }:
    {
      inherit name icon categories;
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=${url} --class=${name}";
      terminal = false;
    };
in
{
  xdg.desktopEntries = {
    youtube = mkWebApp {
      name = "YouTube";
      url = "https://youtube.com";
    };

    youtube-music = mkWebApp {
      name = "YouTube Music";
      url = "https://music.youtube.com";
    };

    whatsapp = mkWebApp {
      name = "WhatsApp";
      url = "https://web.whatsapp.com";
    };

    tidal = mkWebApp {
      name = "Tidal";
      url = "https://tidal.com";
    };

    nix-search = mkWebApp {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
    };

    deepseek = mkWebApp {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
    };

    gemini = mkWebApp {
      name = "Gemini";
      url = "https://gemini.google.com/";
    };

    my-nixos = mkWebApp {
      name = "My NixOS";
      url = "https://mynixos.com/";
    };

    github = mkWebApp {
      name = "GitHub";
      url = "https://github.com";
    };
  };
}
