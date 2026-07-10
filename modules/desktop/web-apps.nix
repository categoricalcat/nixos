{
  pkgs,
  lib,
  ...
}:

let
  webApps = {
    youtube = {
      name = "YouTube";
      url = "https://www.youtube.com/";
    };

    youtube-music = {
      name = "YouTube Music";
      url = "https://music.youtube.com/";
    };

    whatsapp = {
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
    };

    nix-search = {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
    };

    deepseek = {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
    };

    gemini = {
      name = "Gemini";
      url = "https://gemini.google.com/";
    };

    my-nixos = {
      name = "My NixOS";
      url = "https://mynixos.com/";
    };

    github = {
      name = "GitHub";
      url = "https://github.com/";
    };

    bitwarden-web = {
      name = "Bitwarden Web";
      url = "https://vault.bitwarden.com/";
    };

    f1tv = {
      name = "F1 TV";
      url = "https://f1tv.formula1.com/";
    };

    forgejo = {
      name = "Forgejo.git";
      url = "https://git.fufu.land/";
    };

    tiktok = {
      name = "TikTok";
      url = "https://www.tiktok.com/";
    };

    instagram = {
      name = "Instagram";
      url = "https://www.instagram.com/";
    };

    mercado-livre = {
      name = "Mercado Livre";
      url = "https://www.mercadolivre.com.br/";
    };
  };

  chromeCustomized = pkgs.google-chrome.override {
    commandLineArgs = lib.concatStringsSep " " (
      map lib.escapeShellArg [
        "--enable-zero-copy"
        "--ozone-platform-hint=auto"
        "--enable-features=AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,UseMultiPlaneFormatForHardwareVideo,WaylandOverlayDelegation"
        "--no-first-run"
        "--no-default-browser-check"
      ]
    );
  };

  webAppDesktopItems = lib.mapAttrsToList (
    id: app:
    pkgs.makeDesktopItem {
      name = "chrome-webapp-${id}";
      desktopName = app.name;
      exec = "${lib.getExe chromeCustomized} --profile-directory=Default --app=${app.url}";
      icon = "google-chrome"; # Fallback icon
      categories = [
        "Network"
        "WebBrowser"
      ];
    }
  ) webApps;

in
{
  programs.chromium = {
    enable = true;
  };

  environment.systemPackages = [
    chromeCustomized
  ]
  ++ webAppDesktopItems;

  xdg.mime.defaultApplications = {
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
    "text/html" = "google-chrome.desktop";
  };
}
