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

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether tailscaled may point systemd-resolved at MagicDNS. A host that
        must keep exactly one resolver path turns this off, because
        `--accept-dns=true` adds a second `~.` link resolver alongside the one
        networkd declares.
      '';
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
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
            "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
            "--advertise-exit-node=${if cfg.routingMode == "both" then "true" else "false"}"
          ]
        else
          [
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
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

      # nixpkgs makes `tailscaled-set` a oneshot `wantedBy` the daemon, so it
      # runs only when `tailscaled` starts. That is why a deploy declaring
      # `--accept-dns=false` left the daemon holding `true`: the switch did not
      # restart `tailscaled`, so the setter never ran. A finished oneshot is
      # `inactive (dead)`, and `switch-to-configuration` walks only active
      # units, so it is invisible there too — a changed unit file cannot restart
      # it. `RemainAfterExit` keeps it `active (exited)`, which puts it back in
      # that walk: the start script embeds every flag, so a flag change alters
      # the unit file and the next switch re-runs `tailscale set`. The daemon is
      # never restarted.
      systemd.services.tailscaled-set.serviceConfig.RemainAfterExit = true;

      networking.firewall = {
        # Clients trust the overlay wholesale (lan-mouse, distributed builds);
        # servers and routers declare explicit ports in their host firewalls.
        trustedInterfaces = lib.mkIf (!isServer) [ config.services.tailscale.interfaceName ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "tailscale-up" ''
          exec tailscale up --reset ${lib.escapeShellArgs runtimeFlags} "$@"
        '')
      ];
    };
}
