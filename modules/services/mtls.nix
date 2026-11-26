# Internal service mTLS for the yirukou <-> yifuwuqi hops.
#
# One CA signs a server leaf per host and a client leaf per host. The material
# is NOT committed, NOT in the Nix store, and NOT a sops secret: it lives on
# each host under /persist/keys/mtls/, placed there once out of band, and this
# module only names the paths. That mirrors `hashedPasswordFile =
# "/persist/keys/passwords/root"`: Nix declares where identity lives, never
# what it contains.
#
# A host needs five files: the shared CA cert plus its own server and client
# pairs. No peer certificate is ever read, so no peer key ever travels.
#
# Signing is offline. Rotation is: sign new leaves, copy, restart. No code
# change and no rebuild.
#
# nginx verifies an upstream against `proxy_ssl_name` only, and it rejects an
# IP literal even when the certificate carries the matching IP SAN, so
# `upstreamTls` names the peer explicitly.
{
  allAddresses,
  config,
  lib,
  ...
}:

let
  cfg = config.yi.mtls;
  hostName = config.networking.hostName;

  # The single peer each ingress host talks to, taken from the monitoring
  # registry rather than restated here.
  inherit (allAddresses) monitoring;
  peer =
    if hostName == monitoring.centralHost then
      monitoring.proxyHost
    else if hostName == monitoring.proxyHost then
      monitoring.centralHost
    else
      throw "yi.mtls: ${hostName} is neither ${monitoring.centralHost} nor ${monitoring.proxyHost}";

  dir = "/persist/keys/mtls";
  file = name: "${dir}/${name}";

  # `ssl_verify_client on` only proves the chain leads to the CA, and both hosts
  # hold leaves from it, so the subject pin is what makes the certificate name
  # the host.
  chainOnly = ''
    ssl_client_certificate ${cfg.caFile};
    ssl_verify_client on;
  '';

  # Every consumer reads these as an unprivileged user, so the directory and
  # files are root:mtls and each reader joins the group.
  mtlsUsers =
    lib.optionals config.services.nginx.enable [ "nginx" ]
    ++ lib.optionals config.services.prometheus.enable [ "prometheus" ]
    ++ lib.optionals config.services.vector.enable [ "vector" ];

  # Ports the peer may open to `target`, derived once from the registry so the
  # nftables allowlist below is generated rather than retyped. SSH and
  # Tailscale are Decision 6 exceptions and are listed here because the table
  # only logs: an exception that is absent would show up as noise, not as a
  # break.
  peerPorts =
    target:
    let
      t = allAddresses.hosts.${target};
    in
    {
      tcp = [
        t.services.ingress.port
        t.ssh.listenPort
        22
      ]
      ++ lib.optionals (target == monitoring.proxyHost) [
        853 # AdGuard DoT: the resolver hop (Decision 3)
        443 # public vhosts, hairpin clients
      ];
      udp = [ config.services.tailscale.port ];
    };
  # Peer addresses split by family: nftables matches one family per
  # expression, so a single `daddr` set cannot hold both.
  peerAddressesByFamily =
    target:
    let
      all = lib.unique (
        let
          t = allAddresses.hosts.${target};
        in
        [
          t.network.lan.ipv4.host
          t.network.lan.ipv6.host
          t.network.vpn.ipv4.host
        ]
        ++ lib.optional (t.network.vpn ? ipv6) t.network.vpn.ipv6.host
      );
    in
    {
      v4 = lib.filter (a: !lib.hasInfix ":" a) all;
      v6 = lib.filter (lib.hasInfix ":") all;
    };
in
{
  options.yi.mtls = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require mutual TLS on the inter-host service hops.";
    };

    caFile = lib.mkOption {
      type = lib.types.str;
      default = file "service-ca.crt";
      description = "Internal CA that signs every inter-host certificate.";
    };

    serverCert = lib.mkOption {
      type = lib.types.str;
      default = file "${hostName}-server.crt";
      description = "This host's server leaf.";
    };

    serverKey = lib.mkOption {
      type = lib.types.str;
      default = file "${hostName}-server.key";
      description = "Private key for {option}`serverCert`.";
    };

    clientCert = lib.mkOption {
      type = lib.types.str;
      default = file "${hostName}-client.crt";
      description = "This host's client leaf, presented on outbound requests.";
    };

    clientKey = lib.mkOption {
      type = lib.types.str;
      default = file "${hostName}-client.key";
      description = "Private key for {option}`clientCert`.";
    };

    serverVerify = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Server-block directives that demand this host's peer certificate.";
    };

    machineVerify = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Server-block directives for the machine paths, whose callers are scrape and log shippers rather than the peer.";
    };

    upstreamTls = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Location directives that verify and authenticate to the peer.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.mtls = { };

    # Modes are declarative so `systemd-tmpfiles --create` restores them after
    # the out-of-band copy. Type `z` adjusts existing files and is a no-op when
    # one is missing, so a host that has not been seeded yet still boots; it
    # just fails to serve TLS, which is the honest signal. Contents are never
    # managed here.
    systemd.tmpfiles.settings.mtls = {
      "${dir}".d = {
        mode = "0750";
        user = "root";
        group = "mtls";
      };
    }
    // lib.genAttrs [ cfg.caFile cfg.serverCert cfg.serverKey cfg.clientCert cfg.clientKey ] (_: {
      z = {
        mode = "0640";
        user = "root";
        group = "mtls";
      };
    });

    yi.mtls = {
      # A server-level `if` runs in the rewrite phase, before any location, so a
      # rejected identity never reaches a backend.
      serverVerify = chainOnly + ''
        if ($ssl_client_s_dn != "CN=${peer}-client") {
          return 403;
        }
      '';

      # The machine paths serve scrape and log shippers, which present the
      # client leaf of the host they run on: the peer for the log hop, this
      # host itself for a self-scrape. The per-location address allowlist
      # already pins who may connect, so the chain is the admission rule.
      machineVerify = chainOnly;

      upstreamTls = ''
        proxy_ssl_certificate ${cfg.clientCert};
        proxy_ssl_certificate_key ${cfg.clientKey};
        proxy_ssl_trusted_certificate ${cfg.caFile};
        proxy_ssl_verify on;
        proxy_ssl_verify_depth 2;
        proxy_ssl_name ${peer}.lan;
        proxy_ssl_server_name on;
      '';
    };

    # nginx runs as the `nginx` user, not root, and Prometheus and Vector are
    # likewise unprivileged, so each joins mtls instead of gaining privileges.
    systemd.services = lib.genAttrs mtlsUsers (_: {
      serviceConfig.SupplementaryGroups = [ "mtls" ];
    });

    # Log-only peer-egress detector (Decision 7). Shares priority `filter` with
    # the Forgejo runner's `sandbox-egress` table: both are `policy accept`,
    # they key on disjoint selectors (destination address here, `skuid` there),
    # and this one never returns a verdict. It only sees locally generated
    # packets, so routed tailnet and WAN traffic is untouched.
    networking.nftables.tables.mtls-peer = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority filter; policy accept;
          ip daddr { ${lib.concatStringsSep ", " (peerAddressesByFamily peer).v4} } jump to_peer
          ip6 daddr { ${lib.concatStringsSep ", " (peerAddressesByFamily peer).v6} } jump to_peer
        }

        chain to_peer {
          ct state established,related return
          meta l4proto { icmp, ipv6-icmp } return
          tcp dport { ${lib.concatMapStringsSep ", " toString (peerPorts peer).tcp} } return
          udp dport { ${lib.concatMapStringsSep ", " toString (peerPorts peer).udp} } return
          # UPnP IGD discovery, not a service hop. A client on this host asks
          # the default gateway for a port mapping: NAT-PMP on 5351 and a
          # unicast SSDP M-SEARCH on 1900, from one socket, in the same
          # instant. Nothing binds either port on the peer and no host runs an
          # IGD, so every probe goes unanswered — measured 2026-11-26 at ~10/min
          # for 5351 and ~2.5/min for 1900, all unicast to the gateway, with no
          # matching reply. Silenced here so the detector keeps reporting only
          # flows that could become a hop; the sender itself is container-side
          # and unidentified, which is harmless while no IGD exists.
          udp dport { 1900, 5351 } return
          limit rate 5/second burst 10 packets log prefix "mtls-peer: " level warn
        }
      '';
    };
  };
}
