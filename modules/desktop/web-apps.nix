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
    let
      # If isolated, use a dedicated user data directory and basic password store
      # We use a wrapper script to avoid Desktop Entry quoting issues with $HOME
      execCmd =
        if isolate then
          let
            script = pkgs.writeShellScript "launch-${icon}-isolated" ''
              exec ${pkgs.google-chrome}/bin/google-chrome-stable \
                --user-data-dir="$HOME/.config/google-chrome-${icon}" \
                --password-store=basic \
                --app="${url}" \
                --class="${name}"
            '';
          in
          "${script}"
        else
          "${pkgs.google-chrome}/bin/google-chrome-stable --app=${url} --class=${name}";
    in
    {
      inherit
        name
        icon
        categories
        comment
        ;
      exec = execCmd;
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
