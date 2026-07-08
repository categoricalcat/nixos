{
  config,
  pkgs,
  ...
}:

let
  inherit (pkgs) lib;
  inherit (pkgs.lib.strings) toLower replaceStrings;
  chrome = config.programs.google-chrome.finalPackage;
  chromeFeatures = [
    "AcceleratedVideoDecodeLinuxZeroCopyGL"
    "AcceleratedVideoEncoder"
    "UseMultiPlaneFormatForHardwareVideo"
    "WaylandOverlayDelegation"
  ];

  mkWebApp =
    {
      name,
      url,
      icon ? toLower (replaceStrings [ " " ] [ "-" ] name),
      startupWMClass ? name,
      categories ? [
        "Network"
        "WebBrowser"
      ],
      isolate ? false,
      profile ? null,
      extraArgs ? [ ],
      comment ? "Web Application",
      routePatterns ? [ ],
      mimeTypes ? [ ],
    }:
    let
      profileName =
        if profile != null then
          profile
        else if isolate then
          icon
        else
          "webapps";
      launcherArgs = lib.concatStringsSep " " (
        map lib.escapeShellArg (
          [
            "--no-first-run"
            "--no-default-browser-check"
          ]
          ++ extraArgs
        )
      );
      launcher = pkgs.writeShellScript "launch-${icon}" ''
        exec ${chrome}/bin/google-chrome-stable ${launcherArgs} \
          "--user-data-dir=$HOME/.config/google-chrome-${profileName}" \
          --app="''${1:-${url}}" \
          --class=${lib.escapeShellArg startupWMClass}
      '';
    in
    {
      inherit
        name
        icon
        categories
        comment
        routePatterns
        launcher
        ;

      exec = "${launcher} %u";
      terminal = false;
      mimeType = mimeTypes;
      settings = {
        StartupWMClass = startupWMClass;
      };
    };

  webApps = {
    youtube = mkWebApp {
      name = "YouTube";
      url = "https://youtube.com";
      categories = [
        "AudioVideo"
        "Video"
      ];
      comment = "Watch YouTube Videos";
      routePatterns = [
        "m.youtube.com"
        "youtube.com"
        "www.youtube.com"
        "youtu.be"
      ];
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
      routePatterns = [ "music.youtube.com" ];
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
      routePatterns = [ "web.whatsapp.com" ];
    };

    nix-search = mkWebApp {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "Search Nix Packages";
      routePatterns = [ "search.nixos.org" ];
    };

    deepseek = mkWebApp {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
      categories = [ "Network" ];
      comment = "DeepSeek AI Chat";
      routePatterns = [ "chat.deepseek.com" ];
    };

    gemini = mkWebApp {
      name = "Gemini";
      url = "https://gemini.google.com/";
      categories = [ "Network" ];
      comment = "Google Gemini AI";
      routePatterns = [ "gemini.google.com" ];
    };

    my-nixos = mkWebApp {
      name = "My NixOS";
      url = "https://mynixos.com/";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "NixOS Options and Packages Reference";
      routePatterns = [
        "*.mynixos.com"
        "mynixos.com"
      ];
    };

    github = mkWebApp {
      name = "GitHub";
      url = "https://github.com";
      categories = [
        "Development"
        "RevisionControl"
      ];
      comment = "GitHub Repository Hosting";
      routePatterns = [
        "*.github.com"
        "github.com"
      ];
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
      routePatterns = [ "vault.bitwarden.com" ];
    };

    f1tv = mkWebApp {
      name = "F1 TV";
      url = "https://f1tv.formula1.com/";
      categories = [
        "AudioVideo"
        "Video"
      ];
      comment = "Formula 1 TV";
      routePatterns = [ "f1tv.formula1.com" ];
    };

    forgejo = mkWebApp {
      name = "Forgejo.git";
      url = "https://git.fufu.land";
      categories = [
        "Development"
        "RevisionControl"
      ];
      comment = "Git Repository Hosting";
      routePatterns = [ "git.fufu.land" ];
    };

    tiktok = mkWebApp {
      name = "TikTok";
      url = "https://www.tiktok.com";
      categories = [
        "Network"
        "WebBrowser"
      ];
      comment = "TikTok Web";
      routePatterns = [
        "*.tiktok.com"
        "tiktok.com"
      ];
    };

    instagram = mkWebApp {
      name = "Instagram";
      url = "https://www.instagram.com";
      categories = [
        "Network"
        "WebBrowser"
      ];
      comment = "Instagram Web";
      routePatterns = [
        "*.instagram.com"
        "instagram.com"
      ];
    };

    mercado-livre = mkWebApp {
      name = "Mercado Livre";
      url = "https://www.mercadolivre.com.br";
      categories = [
        "Network"
        "WebBrowser"
      ];
      comment = "Mercado Livre Web";
      routePatterns = [
        "*.mercadolivre.com.br"
        "mercadolivre.com.br"
      ];
    };
  };

  # Strip internal attrs before passing to desktopEntries.
  desktopEntries = builtins.mapAttrs (
    _: app:
    removeAttrs app [
      "routePatterns"
      "launcher"
    ]
  ) webApps;
in
{
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--enable-zero-copy"
      "--ozone-platform-hint=auto"
      "--enable-features=${lib.concatStringsSep "," chromeFeatures}"
    ];
  };

  xdg.desktopEntries = desktopEntries;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [ "google-chrome.desktop" ];
      "x-scheme-handler/https" = [ "google-chrome.desktop" ];
      "text/html" = [ "google-chrome.desktop" ];
    };
  };
}
