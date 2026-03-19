{ pkgs, ... }:

let
  mkWebApp =
    {
      name,
      url,
      icon ? "floorp",
      categories ? [
        "Network"
        "WebBrowser"
      ],
    }:
    {
      inherit name icon categories;
      exec = "${pkgs.floorp}/bin/floorp --class ${name} ${url}";
      terminal = false;
    };
in
{
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
