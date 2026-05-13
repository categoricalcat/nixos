{
  allAddresses,
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
  cfg = config.yi.tailscale;
  isServer = cfg.routingMode == "server" || cfg.routingMode == "both";
in
{
  options.yi.tailscale = {
    routingMode = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
        "both"
      ];
      default = "client";
      description = ''
        client: accept subnet routes and optional exit node.
        server: advertise routes as subnet router.
        both: subnet router + exit node.
      '';
    };

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Subnets to advertise via Tailscale (e.g. [\"10.42.0.0/24\"]).";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether client-mode hosts should accept advertised Tailscale subnet routes.";
    };

    exitNodeHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = allAddresses.hosts.yirukou.network.tailscale.ipv4.host;
      description = "Tailscale IP of the exit node to use (client mode).";
    };
  };

  config = {
    services.tailscale = {
      enable = lib.mkDefault true;
      package = unstable.tailscale;
      useRoutingFeatures = if isServer then "server" else "client";
      extraUpFlags =
        if isServer then
          [ "--accept-dns=true" ]
          ++ lib.optional (
            cfg.advertiseRoutes != [ ]
          ) "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
          ++ lib.optional (cfg.routingMode == "both") "--advertise-exit-node"
        else
          [
            "--accept-dns=true"
            "--accept-routes=${if cfg.acceptRoutes then "true" else "false"}"
          ]
          ++ lib.optionals (cfg.exitNodeHost != null) [
            "--exit-node=${cfg.exitNodeHost}"
            "--exit-node-allow-lan-access=true"
          ];
    };

    networking.firewall = {
      trustedInterfaces = [ config.services.tailscale.interfaceName ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
  };
}
