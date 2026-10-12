{ pkgs, addresses, ... }:

let
  cockpit = addresses.services.cockpit;
  port = toString cockpit.port;
in
{
  services.cockpit = {
    enable = true;
    inherit (cockpit) port;
    plugins = with pkgs; [
      cockpit-podman
      cockpit-files
      cockpit-dockermanager
      cockpit-machines
      cockpit-zfs
    ];
    allowed-origins = [
      "http://localhost:${port}"
      "https://localhost:${port}"
      "http://${addresses.hostName}.local:${port}"
      "https://${addresses.hostName}.local:${port}"
      "http://${addresses.network.vpn.ipv4.host}:${port}"
      "https://${addresses.network.vpn.ipv4.host}:${port}"
      "https://${cockpit.domain}"
    ];
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };

  # NixOS ships kexec for fast reboot (boot.kexec), which makes Cockpit
  # show its Fedora kdump page and the "install kexec-tools" alert.
  # That page wants kdump.service, which NixOS does not provide.
  environment.etc."cockpit/kdump.override.json".text = builtins.toJSON {
    conditions = [
      { "path-exists" = "/var/empty/cockpit-kdump-enabled"; }
    ];
  };

  environment.systemPackages = with pkgs; [
    sysstat
  ];

  systemd.services.cockpit = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
