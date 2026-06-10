{ pkgs, ... }:

let
  inherit (pkgs.lib.strings) toLower replaceStrings;

  mkWebApp =
    {
      name,
      url,
      # Convert "YouTube Music" -> "youtube-music" to match icon theme files
      icon ? toLower (replaceStrings [ " " ] [ "-" ] name),
      categories ? [
        "Network"
        "WebBrowser"
      ],
      isolate ? false,
      comment ? "Web Application",
    }:
    {
      inherit
        name
        icon
        categories
        comment
        ;

      exec =
        let
          userDataDirArg = pkgs.lib.optionalString isolate ''--user-data-dir="$HOME/.config/google-chrome-${icon}"'';
        in
        toString (
          pkgs.writeShellScript "launch-${icon}" ''
            exec ${pkgs.google-chrome}/bin/google-chrome-stable ${userDataDirArg} \
              --app="${url}" \
              --class="${name}"
          ''
        );

      terminal = false;
      settings = {
        StartupWMClass = name;
      };
    };
in
{
  xdg.desktopEntries = {
    youtube = mkWebApp {
      name = "YouTube";
      url = "https://youtube.com";
      categories = [
        "AudioVideo"
        "Video"
      ];
      comment = "Watch YouTube Videos";
    };

    youtube-music = mkWebApp {
      name = "YouTube Music";
      url = "https://music.youtube.com";
      categories = [
        "AudioVideo"
        "Audio"
        "Player"
      ];
      comment = "Listen to YouTube Music";
    };

    whatsapp = mkWebApp {
      name = "WhatsApp";
      url = "https://web.whatsapp.com";
      isolate = true;
      categories = [
        "Network"
        "Chat"
      ];
      comment = "WhatsApp Web Client";
    };

    nix-search = mkWebApp {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "Search Nix Packages";
    };

    deepseek = mkWebApp {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
      categories = [ "Network" ];
      comment = "DeepSeek AI Chat";
    };

    gemini = mkWebApp {
      name = "Gemini";
      url = "https://gemini.google.com/";
      categories = [ "Network" ];
      comment = "Google Gemini AI";
    };

    my-nixos = mkWebApp {
      name = "My NixOS";
      url = "https://mynixos.com/";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "NixOS Options and Packages Reference";
    };

    github = mkWebApp {
      name = "GitHub";
      url = "https://github.com";
      categories = [
        "Development"
        "RevisionControl"
      ];
      comment = "GitHub Repository Hosting";
    };

    bitwarden-web = mkWebApp {
      name = "Bitwarden Web";
      url = "https://vault.bitwarden.com";
      isolate = true;
      categories = [
        "Settings"
        "Security"
      ];
      comment = "Password Manager";
    };
  };
}
