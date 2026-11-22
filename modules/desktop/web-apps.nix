{
  allAddresses,
  pkgs,
  lib,
  chromiumDictionaries,
  ...
}:

let
  themeAssets = import ../theme-assets.nix { inherit pkgs; };

  webApps = {
    youtube = {
      name = "YouTube";
      url = "https://www.youtube.com/";
    };

    youtube-music = {
      name = "YouTube Music";
      url = "https://music.youtube.com/";
    };

    nix-search = {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
      icon = "distributor-logo-nixos.svg";
    };

    deepseek = {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
      icon = "browser.svg";
    };

    gemini = {
      name = "Gemini";
      url = "https://gemini.google.com/";
    };

    kimi = {
      name = "Kimi";
      url = "https://kimi.ai/";
      icon = "browser.svg";
    };

    my-nixos = {
      name = "My NixOS";
      url = "https://mynixos.com/";
      icon = "distributor-logo-nixos.svg";
    };

    github = {
      name = "GitHub";
      url = "https://github.com/";
    };

    bitwarden-web = {
      name = "Bitwarden Web";
      url = "https://vault.bitwarden.com/";
      icon = "bitwarden.svg";
    };

    f1tv = {
      name = "F1 TV";
      url = "https://f1tv.formula1.com/";
      icon = "f1-2017.svg";
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
      icon = "shop.svg";
    };

    songsterr = {
      name = "Songsterr";
      url = "https://www.songsterr.com/";
      icon = "guitar.svg";
    };
  }
  // lib.mapAttrs (id: s: {
    inherit (s) name;
    url = "https://${s.domain}/";
    icon = s.desktopIcon or "${id}.svg";
  }) (lib.filterAttrs (_: s: s ? name) allAddresses.hosts.yifuwuqi.services);

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
      icon = "${themeAssets.icons.package}/share/icons/${themeAssets.icons.dark}/64x64/apps/${app.icon or "${id}.svg"}";
      categories = [
        "Network"
        "WebBrowser"
      ];
    }
  ) webApps;

  zapzapCustomized = pkgs.zapzap.override {
    dictionaries = chromiumDictionaries;
  };
in
{
  programs.chromium = {
    enable = true;
  };

  environment.systemPackages = [
    chromeCustomized
    zapzapCustomized
  ]
  ++ webAppDesktopItems;
}
