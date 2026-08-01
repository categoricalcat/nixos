# Locale and internationalization configuration module

{
  pkgs,
  config,
  lib,
  ...
}:

let
  # Chromium bdic dictionaries for Qt WebEngine spellchecking (e.g. zapzap).
  # These are a different format from the hunspell .dic/.aff files below and
  # are looked up via QTWEBENGINE_DICTIONARIES_PATH, not DICPATH.
  ptBrChromiumDict = pkgs.hunspellDictsChromium.mkDictFromChromium {
    shortName = "pt-br";
    dictFileName = "pt-BR-3-0.bdic";
    shortDescription = "Portuguese (Brazil)";
  };
in

{
  _module.args.chromiumDictionaries = with pkgs.hunspellDictsChromium; [
    ptBrChromiumDict
    en-gb
    en-us
  ];

  time.timeZone = "America/Sao_Paulo";

  environment = {
    systemPackages = lib.mkIf (!config.serverMode.headless) (
      with pkgs;
      [
        hunspell
        hunspellDicts.pt_BR
        hunspellDicts.en_US
        hunspellDicts.en_GB-ise
      ]
    );

    sessionVariables = {
      TZ = "America/Sao_Paulo";

      DICPATH = lib.mkIf (
        !config.serverMode.headless
      ) "/run/current-system/sw/share/hunspell:/run/current-system/sw/share/myspell";
    };
  };

  i18n = {
    defaultLocale = "pt_BR.UTF-8";
    extraLocales = [
      "pt_BR.UTF-8/UTF-8"
      "en_GB.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_MEASUREMENT = "pt_BR.UTF-8";
      LC_MONETARY = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_NUMERIC = "pt_BR.UTF-8";
      LC_PAPER = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
      LC_TIME = "pt_BR.UTF-8";
      LC_ALL = "pt_BR.UTF-8";
    };
  };
}
