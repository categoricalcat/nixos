{ pkgs, lib, ... }:

{
  options = {
    desktop.environment = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "niri"
      ];
      default = "gnome";
      description = "Desktop environment to use";
    };
  };

  imports = [
    ./desktop/gnome.nix
    ./desktop/niri.nix
  ];

  config = {
    networking.hostName = "fuyidong";
    networking.networkmanager.enable = true;

    programs = {
      mtr.enable = true;
      xwayland.enable = true;
    };

    console.keyMap = "br-abnt2";

    services.libinput.enable = true;

    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "fufud";

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;

    # Common packages for all desktop environments
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
    ];
  };
}
