{
  config,
  lib,
  pkgs,
  ...
}:

let
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
      default = null;
      description = "Tailscale IP of the exit node to use (client mode).";
    };

    ssh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tailscale SSH.";
    };
  };

  config =
    let
      # Flags that are also valid for `tailscale set`. We feed the exact same
      # list to both `extraUpFlags` (first registration) and `extraSetFlags`
      # (re-applied on every daemon start) so a rebuild always reconciles the
      # daemon's saved prefs with what Nix declares. Without this, a host
      # that registered earlier keeps stale prefs (e.g. ExitNodeID) even
      # after we change exitNodeHost in config, because `tailscale up` is
      # only run on initial auth.
      baseFlags =
        if isServer then
          [
            "--accept-dns=true"
            "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
            "--advertise-exit-node=${if cfg.routingMode == "both" then "true" else "false"}"
          ]
        else
          [
            "--accept-dns=true"
            "--accept-routes=${if cfg.acceptRoutes then "true" else "false"}"
            # An empty value to `--exit-node` clears the pref, so a host
            # that previously had one assigned drops it on the next rebuild.
            "--exit-node=${if cfg.exitNodeHost != null then cfg.exitNodeHost else ""}"
            "--exit-node-allow-lan-access=${if cfg.exitNodeHost != null then "true" else "false"}"
          ];
      runtimeFlags = baseFlags ++ lib.optional cfg.ssh "--ssh";
    in
    {
      services.tailscale = {
        enable = lib.mkDefault true;
        package = pkgs.tailscale;
        useRoutingFeatures = if isServer then "server" else "client";
        extraUpFlags = runtimeFlags;
        extraSetFlags = runtimeFlags;
      };

      networking.firewall = {
        trustedInterfaces = [ config.services.tailscale.interfaceName ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "tailscale-up" ''
          exec sudo tailscale up --reset ${lib.escapeShellArgs runtimeFlags} "$@"
        '')
      ];
    };
}
