{
  pkgs,
  lib,
  ...
}:

let
  themeAssets = import ../theme-assets.nix { inherit pkgs; };
  iconBase = "${themeAssets.icons.package}/share/icons/${themeAssets.icons.dark}/64x64/apps";

  webApps = {
    youtube = {
      name = "YouTube";
      url = "https://www.youtube.com/";
      icon = "${iconBase}/youtube.svg";
    };

    youtube-music = {
      name = "YouTube Music";
      url = "https://music.youtube.com/";
      icon = "${iconBase}/youtube-music.svg";
    };

    whatsapp = {
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
      icon = "${iconBase}/whatsapp.svg";
    };

    nix-search = {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
      icon = "${iconBase}/distributor-logo-nixos.svg";
    };

    deepseek = {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
      icon = "${iconBase}/browser.svg";
    };

    gemini = {
      name = "Gemini";
      url = "https://gemini.google.com/";
      icon = "${iconBase}/gemini.svg";
    };

    my-nixos = {
      name = "My NixOS";
      url = "https://mynixos.com/";
      icon = "${iconBase}/distributor-logo-nixos.svg";
    };

    github = {
      name = "GitHub";
      url = "https://github.com/";
      icon = "${iconBase}/github.svg";
    };

    bitwarden-web = {
      name = "Bitwarden Web";
      url = "https://vault.bitwarden.com/";
      icon = "${iconBase}/bitwarden.svg";
    };

    f1tv = {
      name = "F1 TV";
      url = "https://f1tv.formula1.com/";
      icon = "${iconBase}/f1-2017.svg";
    };

    forgejo = {
      name = "Forgejo.git";
      url = "https://git.fufu.land/";
      icon = "${iconBase}/git.svg";
    };

    tiktok = {
      name = "TikTok";
      url = "https://www.tiktok.com/";
      icon = "${iconBase}/tiktok.svg";
    };

    instagram = {
      name = "Instagram";
      url = "https://www.instagram.com/";
      icon = "${iconBase}/instagram.svg";
    };

    mercado-livre = {
      name = "Mercado Livre";
      url = "https://www.mercadolivre.com.br/";
      icon = "${iconBase}/shop.svg";
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
      icon = app.icon or "${iconBase}/google-chrome.svg"; # Fallback icon
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
