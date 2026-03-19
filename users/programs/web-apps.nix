{ pkgs, ... }:

let
  mkWebApp =
    {
      name,
      url,
      icon ? "google-chrome",
      categories ? [
        "Network"
        "WebBrowser"
      ],
    }:
    {
      inherit name icon categories;
      exec = "google-chrome-stable --app=${url} --class=${name}";
      terminal = false;
    };
in
{
  home.packages = [ pkgs.google-chrome ];

  xdg.desktopEntries = {
    youtube = mkWebApp {
      name = "YouTube";
      url = "https://youtube.com";
    };

    whatsapp = mkWebApp {
      name = "WhatsApp";
      url = "https://web.whatsapp.com";
    };

    tidal = mkWebApp {
      name = "Tidal";
      url = "https://tidal.com";
    };
  };
}
