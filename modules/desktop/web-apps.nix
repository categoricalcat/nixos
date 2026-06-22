{
  config,
  pkgs,
  ...
}:

let
  inherit (pkgs.lib.strings) toLower replaceStrings;
  chrome = config.programs.google-chrome.finalPackage;

  mkWebApp =
    {
      name,
      url,
      icon ? toLower (replaceStrings [ " " ] [ "-" ] name),
      categories ? [
        "Network"
        "WebBrowser"
      ],
      isolate ? false,
      comment ? "Web Application",
      domains ? [ ],
    }:
    let
      userDataDirArg = pkgs.lib.optionalString isolate ''--user-data-dir="$HOME/.config/google-chrome-${icon}"'';
      launcher = pkgs.writeShellScript "launch-${icon}" ''
        exec ${chrome}/bin/google-chrome-stable ${userDataDirArg} \
          --app="''${1:-${url}}" \
          --class="${name}"
      '';
    in
    {
      inherit
        name
        icon
        categories
        comment
        domains
        launcher
        ;

      exec = "${launcher} %U";
      terminal = false;
      settings = {
        StartupWMClass = name;
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
      domains = [
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
      domains = [ "music.youtube.com" ];
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
      domains = [ "web.whatsapp.com" ];
    };

    nix-search = mkWebApp {
      name = "Nix Search";
      url = "https://search.nixos.org/packages";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "Search Nix Packages";
      domains = [ "search.nixos.org" ];
    };

    deepseek = mkWebApp {
      name = "DeepSeek";
      url = "https://chat.deepseek.com/";
      categories = [ "Network" ];
      comment = "DeepSeek AI Chat";
      domains = [ "chat.deepseek.com" ];
    };

    gemini = mkWebApp {
      name = "Gemini";
      url = "https://gemini.google.com/";
      categories = [ "Network" ];
      comment = "Google Gemini AI";
      domains = [ "gemini.google.com" ];
    };

    my-nixos = mkWebApp {
      name = "My NixOS";
      url = "https://mynixos.com/";
      categories = [
        "Development"
        "Documentation"
      ];
      comment = "NixOS Options and Packages Reference";
      domains = [
        "mynixos.com"
        "www.mynixos.com"
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
      domains = [
        "github.com"
        "www.github.com"
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
      domains = [ "vault.bitwarden.com" ];
    };

    f1tv = mkWebApp {
      name = "F1 TV";
      url = "https://f1tv.formula1.com/";
      categories = [
        "AudioVideo"
        "Video"
      ];
      comment = "Formula 1 TV";
      domains = [ "f1tv.formula1.com" ];
    };

    forgejo = mkWebApp {
      name = "Forgejo.git";
      url = "https://git.fufu.land";
      categories = [
        "Development"
        "RevisionControl"
      ];
      comment = "Git Repository Hosting";
      domains = [ "git.fufu.land" ];
    };

    tiktok = mkWebApp {
      name = "TikTok";
      url = "https://www.tiktok.com";
      categories = [
        "Network"
        "WebBrowser"
      ];
      comment = "TikTok Web";
      domains = [
        "tiktok.com"
        "www.tiktok.com"
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
      domains = [
        "instagram.com"
        "www.instagram.com"
      ];
    };
  };

  # Build case branches from webApps that have domains
  routerCases =
    let
      appsWithDomains = pkgs.lib.filterAttrs (_: app: app.domains != [ ]) webApps;
    in
    pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (
        _: app: "  ${pkgs.lib.concatStringsSep "|" app.domains}) exec ${app.launcher} \"$1\" ;;"
      ) appsWithDomains
    );

  urlRouter = pkgs.writeShellScriptBin "url-router" ''
    d="''${1#*://}"; d="''${d%%/*}"
    case "$d" in
    ${routerCases}
    *) exec ${chrome}/bin/google-chrome-stable "$1" ;;
    esac
  '';

  # Strip internal attrs (domains, launcher) before passing to desktopEntries
  desktopEntries = builtins.mapAttrs (
    _: app:
    removeAttrs app [
      "domains"
      "launcher"
    ]
  ) webApps;
in
{
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--enable-zero-copy"
      "--enable-features=AcceleratedVideoDecodeLinuxZeroCopyGL,UseMultiPlaneFormatForHardwareVideo,WaylandOverlayDelegation"
    ];
  };

  xdg.desktopEntries = desktopEntries // {
    url-router = {
      name = "URL Router";
      exec = "${urlRouter}/bin/url-router %U";
      terminal = false;
      categories = [ "Network" ];
      mimeType = [
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [ "url-router.desktop" ];
      "x-scheme-handler/https" = [ "url-router.desktop" ];
      "text/html" = [ "url-router.desktop" ];
    };
  };
}
