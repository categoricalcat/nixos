# Locale and internationalization configuration module

{ config, pkgs, ... }:

{
  # Time zone
  time.timeZone = "America/Sao_Paulo";

  # Default locale
  i18n.defaultLocale = "pt_BR.UTF-8";

  # Additional locale settings (Brazilian Portuguese for specific categories)
  i18n.extraLocaleSettings = {
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
}
