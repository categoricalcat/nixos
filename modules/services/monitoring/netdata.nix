{ pkgs, inputs, ... }:

let
  unstable = import ../../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  services.netdata = {
    enable = true;
    package = unstable.netdata.override { withCloudUi = true; };
    config = {
      global = {
        "memory mode" = "dbengine";
        "update every" = "1";
      };
      web = {
        "bind to" = "127.0.0.1";
        "default port" = "19999";
        "allow connections from" = "localhost 127.0.0.1";
      };
      "plugin:freeipmi" = {
        enabled = "no";
      };
      "plugin:python.d" = {
        enabled = "no";
      };
    };
  };

  systemd.services.netdata = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    preStart = "mkdir -p /tmp/netdata";
  };
}
