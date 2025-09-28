# Desktop environment configuration module (Hyprland)

{ pkgs, ... }:

{
  programs.hyprland.enable = true;
  programs.xwayland.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "Hyprland";
        user = "fufud";
      };
    };
  };

  # Wayland-friendly desktop portals
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  # Wayland environment hints for apps (Electron, Mozilla, Qt)
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
  };

  programs.ssh.forwardX11 = false;

  # Console keymap
  console.keyMap = "us";

  # Audio services (kept minimal here)
  services.pulseaudio.enable = false;
  security.rtkit.enable = false;

  # Disable power management targets
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
