{ pkgs, ... }:

{
  networking.hostName = "fuyidong";
  networking.networkmanager.enable = true;

  programs = {
    mtr.enable = true;
    xwayland.enable = true;
  };

  services = {
    xserver.enable = false;

    desktopManager = {
      gnome = {
        enable = true;
        extraGSettingsOverrides = ''
          [org.gnome.mutter]
          experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
        '';
      };
    };

    displayManager = {
      gdm.enable = true;

      sddm = {
        enable = false;
        wayland = {
          enable = true;
        };
        settings = {
          General.DisplayManager = "wayland";
        };
      };
    };

    gnome = {
      core-apps.enable = true;
      core-developer-tools.enable = false;
      games.enable = false;
    };
  };

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  console.keyMap = "br-abnt2";

  services.libinput.enable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "fufud";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    discord
    discord-ptb
    emacs
    chromium
    vscode-fhs
    code-cursor-fhs
    zsh
    bitwarden-desktop
    git
    kitty
    cloudflared

    gnomeExtensions.user-themes # Essential for applying shell themes
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
  ];
}
