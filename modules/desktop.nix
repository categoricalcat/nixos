# Desktop environment configuration module

{ pkgs, ... }:

{
  # Wayland-based desktop configuration
  services.xserver = {
    enable = true; # Still needed for GDM/GNOME infrastructure

    # Force Wayland for GDM
    displayManager = {
      gdm = {
        enable = true;
        wayland = true; # Ensure GDM runs on Wayland
      };
    };

    # Desktop environment with Wayland
    desktopManager.gnome.enable = true;

    # Disable X11 sessions
    excludePackages = [ pkgs.xterm ];

    # Keyboard layout (works for both X11 and Wayland)
    xkb = {
      layout = "us";
      variant = "alt-intl";
    };
  };

  # Force Wayland for GNOME session
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Hint Electron apps to use Wayland (including Chromium)
  };

  # Disable X11 forwarding
  programs.ssh.forwardX11 = false;

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
