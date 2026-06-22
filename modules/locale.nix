# Locale and internationalization configuration module

{
  pkgs,
  config,
  lib,
  ...
}:

{
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
