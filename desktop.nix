# Desktop environment configuration module

{ config, pkgs, ... }:

{
  # X11 windowing system
  services.xserver = {
    enable = true;

    # Display manager
    displayManager.gdm.enable = true;

    # Desktop environment
    desktopManager.gnome.enable = true;

    # Keyboard layout
    xkb = {
      layout = "us";
      variant = "alt-intl";
    };
  };

  # Console keymap
  console.keyMap = "us";

  # Audio services (disabled in favor of custom setup)
  services.pulseaudio.enable = false;
  security.rtkit.enable = false;

  # Display manager auto-login
  services.displayManager.autoLogin = {
    enable = true;
    user = "fufud";
  };

  # Workaround for GNOME autologin
  # https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = true;
  systemd.services."autovt@tty1".enable = true;

  # Disable power management targets
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
