{ pkgs, ... }:

{
  networking.hostName = "fuyidong";
  networking.networkmanager.enable = true;

  programs.xwayland.enable = true;
  services.xserver.enable = true;

  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
    '';
  };

  services.xserver.xkb = {
    layout = "br";
    variant = "thinkpad";
  };

  console.keyMap = "br-abnt2";

  services.libinput.enable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "fufud";

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
    zsh
    bitwarden-desktop
    git
    kitty
    cloudflared
  ];

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
}
