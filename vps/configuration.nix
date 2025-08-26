# Minimal VPS configuration to run FRP server (frps)

{
  pkgs,
  config,
  lib,
  ...
}:

{
  imports = [ ];

  system.stateVersion = "25.11";

  networking.hostName = "vps";

  # No SSH on VPS; install only Emacs
  services.openssh.enable = false;
  environment.systemPackages = with pkgs; [
    emacs
    git
    btop
  ];

  # Make this configuration evaluatable in CI without real disks/bootloader
  boot.isContainer = true;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=512M"
    ];
  };
  swapDevices = [ ];

  # Enable FRP server with minimal upstream module
  services.frp = {
    enable = true;
    role = "server";
    settings = {
      bindPort = 7000;
    };
  };

  # Provide token via sops template with placeholders (no secrets in Nix store)
  sops.secrets."tokens/frp" = { };

  sops.templates."frps.toml" = {
    content = ''
      bindPort = 7000

      [auth]
      method = "token"
      token = "${config.sops.placeholder."tokens/frp"}"
    '';
    owner = "root";
    group = "root";
    mode = "0640";
    path = "/run/frp/frps.toml";
  };

  # Make frps use the runtime-rendered template
  systemd.services.frp.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.frp}/bin/frps --strict_config -c ${config.sops.templates."frps.toml".path}";

  # Open firewall only for frps bindPort
  networking.firewall.allowedTCPPorts = [ 7000 ];
}
