# Config contracts and repo checks.
#
# Contracts are pure-evaluation security invariants over the declared
# configuration (`self.nixosConfigurations`): they assert current policy,
# never aspiration (docs/src/plans/general-plan.md, Decisions). Failures throw
# `contract <name> failed for <host>: <why>` at evaluation time, so
# `nix flake check --no-build` and CI fail early without building.
{
  self,
  lib,
  ...
}:
let
  addresses = import ../modules/addresses.nix;

  contract =
    name: host: cond: why:
    if cond then
      "contract ${name} passed for ${host}"
    else
      throw "contract ${name} failed for ${host}: ${why}";
  contractIssues =
    name: host: issues:
    contract name host (issues == [ ]) (lib.concatStringsSep "; " issues);

  # Generated configs indent with spaces only.
  lines = text: map (l: lib.concatStrings (lib.match " *(.*)" l)) (lib.splitString "\n" text);

  # Lines of the `Match User <user>` sshd_config block until the next Match (or EOF).
  matchBlock =
    user: text:
    (lib.foldl'
      (
        acc: l:
        if acc.state == "done" then
          acc
        else if acc.state == "in" then
          if lib.hasPrefix "Match " l then
            acc // { state = "done"; }
          else
            acc // { result = acc.result ++ [ l ]; }
        else if l == "Match User ${user}" then
          {
            state = "in";
            result = [ l ];
          }
        else
          acc
      )
      {
        state = "before";
        result = [ ];
      }
      (lines text)
    ).result;

  # --- fleet-baseline --------------------------------------------------------
  fleetBaseline = lib.mapAttrsToList (
    name: cfg:
    contract "fleet-baseline" name (
      !cfg.config.security.sudo.enable
    ) "security.sudo.enable must be false"
  ) self.nixosConfigurations;

  # --- sshd-hardening --------------------------------------------------------
  # LAN `Match Address` password block is policy, not drift.
  gateHosts = lib.filter (
    n: lib.hasInfix "Match User ai" self.nixosConfigurations.${n}.config.services.openssh.extraConfig
  ) (lib.attrNames self.nixosConfigurations);

  authOff = [
    "AuthenticationMethods publickey"
    "PasswordAuthentication no"
    "KbdInteractiveAuthentication no"
    "X11Forwarding no"
    "AllowTcpForwarding no"
    "AllowAgentForwarding no"
    "AllowStreamLocalForwarding no"
    "PermitTTY no"
  ];

  sshdHardening = lib.map (
    name:
    let
      cfg = self.nixosConfigurations.${name}.config.services.openssh;
      ai = matchBlock "ai" cfg.extraConfig;
      nb = matchBlock "nix-builder" cfg.extraConfig;
      issues =
        lib.optional (
          cfg.settings.PasswordAuthentication || cfg.settings.KbdInteractiveAuthentication
        ) "default settings must keep both password paths off"
        ++ lib.optional (ai == [ ]) "Match User ai block missing"
        ++ lib.optional (
          ai != [ ] && !lib.all (l: lib.elem l ai) authOff
        ) "ai block missing hardening lines"
        ++ lib.optional (
          ai != [ ] && !lib.any (l: lib.match "ForceCommand /nix/store/[a-z0-9]+-ai-gate" l != null) ai
        ) "ai block must ForceCommand the ai-gate wrapper"
        ++ lib.optional (nb == [ ]) "Match User nix-builder block missing"
        ++ lib.optional (
          nb != [ ] && !lib.all (l: lib.elem l nb) (authOff ++ [ "PermitOpen none" ])
        ) "nix-builder block missing hardening lines"
        ++ lib.optional (
          nb != [ ] && !lib.elem "ForceCommand nix-daemon --stdio" nb
        ) "nix-builder must ForceCommand nix-daemon --stdio";
    in
    contractIssues "sshd-hardening" name issues
  ) gateHosts;

  # Every registry host runs the gate; yichuang is unregistered and carries none.
  gateCoverage =
    let
      expected = lib.attrNames addresses.hosts;
    in
    contract "sshd-gate-coverage" "fleet" (
      gateHosts == expected
    ) "hosts running the ai gate ${toString gateHosts} != registry hosts ${toString expected}";

  # --- proxy-allowlist -------------------------------------------------------
  # Every proxying/file-serving vhost/location enforces restrictedProxyConfig;
  # static `return` test and redirect locations are exempt.
  proxyAllowlist =
    let
      cfg = self.nixosConfigurations.yirukou.config;
      lan = addresses.hosts.yirukou.network.lan;
      expected = [
        "allow ${lan.ipv4.cidr};"
        "allow ${lan.ipv6.cidr};"
        "deny all;"
      ];
      allowDeny = text: lib.filter (l: lib.hasPrefix "allow " l || lib.hasPrefix "deny " l) (lines text);
      served =
        loc:
        loc.proxyPass != null
        || loc.root != null
        || loc.alias != null
        || loc.tryFiles != null
        || lib.hasInfix "proxy_pass" loc.extraConfig;
      violating = lib.concatMap (
        vname:
        let
          vhost = cfg.services.nginx.virtualHosts.${vname};
        in
        lib.optional (vhost.root != null && allowDeny vhost.extraConfig != expected) "${vname} (vhost root)"
        ++ lib.concatMap (
          lname:
          let
            loc = vhost.locations.${lname};
          in
          lib.optional (served loc && allowDeny loc.extraConfig != expected) "${vname}/${lname}"
        ) (lib.attrNames vhost.locations)
      ) (lib.attrNames cfg.services.nginx.virtualHosts);
    in
    contract "proxy-allowlist" "yirukou" (violating == [ ])
      "locations whose allow/deny sequence is not exactly the registry LAN CIDRs then deny all: ${toString violating}";

  # --- edge-no-tcp -----------------------------------------------------------
  # yirukou keeps filterForward on, opens no global TCP or port ranges (only
  # Tailscale's UDP port globally), and keeps WAN interfaces UDP-51820-only.
  edgeNoTcp =
    let
      cfg = self.nixosConfigurations.yirukou.config;
      fw = cfg.networking.firewall;
      wan = addresses.hosts.yirukou.network.wan;
      issues =
        lib.optional (!fw.filterForward) "filterForward!=true"
        ++ lib.optional (fw.allowedTCPPorts != [ ]) "global TCP ports (${toString fw.allowedTCPPorts})"
        ++ lib.optional (fw.allowedTCPPortRanges != [ ]) "global TCP port ranges"
        ++ lib.optional (fw.allowedUDPPortRanges != [ ]) "global UDP port ranges"
        ++ lib.optional (lib.any (
          p: p != cfg.services.tailscale.port
        ) fw.allowedUDPPorts) "global UDP ports beyond tailscale (${toString fw.allowedUDPPorts})"
        ++
          lib.concatMap
            (
              i:
              if !(fw.interfaces ? ${i}) then
                [ "${i} undeclared" ]
              else
                let
                  f = fw.interfaces.${i};
                in
                lib.optional (
                  f.allowedTCPPorts != [ ]
                  || f.allowedTCPPortRanges != [ ]
                  || f.allowedUDPPortRanges != [ ]
                  || lib.any (p: p != 51820) f.allowedUDPPorts
                ) i
            )
            [
              wan.primary.interface
              wan.fallback.interface
            ];
    in
    contractIssues "edge-no-tcp" "yirukou" issues;

  # --- exporter-source-scope (INTERIM) ---------------------------------------
  # Delete together with extraInputRules at mTLS Phase 4 acceptance
  # (docs/src/plans/mtls-architecture-plan.md).
  exporterSourceScope =
    let
      centralLan = addresses.hosts.${addresses.monitoring.centralHost}.network.lan.ipv4.host;
      saddr =
        l:
        let
          m = lib.match ".*ip saddr ([^ ]+).*" l;
        in
        if m == null then null else builtins.head m;
    in
    lib.map (
      h:
      let
        cfg = self.nixosConfigurations.${h}.config;
        openExporters = lib.filter (
          e:
          let
            ex = cfg.services.prometheus.exporters.${e};
          in
          ex.enable && ex.openFirewall
        ) (lib.attrNames addresses.monitoring.exporters);
        rs = lib.filter (l: lib.hasInfix "tcp dport" l && lib.hasInfix "accept" l) (
          lines cfg.networking.firewall.extraInputRules
        );
        bad = lib.filter (l: saddr l != centralLan) rs;
        issues =
          lib.optional (
            openExporters != [ ]
          ) "exporters with openFirewall=true bypass source scoping: ${toString openExporters}"
          ++ lib.optional (rs == [ ]) "no exporter accept rule in extraInputRules"
          ++ lib.optional (bad != [ ]) "exporter accept rules not scoped to ${centralLan}: ${toString bad}";
      in
      contractIssues "exporter-source-scope" h issues
    ) (lib.filter (h: h != addresses.monitoring.centralHost) addresses.monitoring.scrapeHosts);

  # --- deploy registry derivation (A4) ---------------------------------------
  deployNodes = lib.attrNames self.deploy.nodes;
  registryDeployable = lib.attrNames (lib.filterAttrs (_: host: host.deploy) addresses.hosts);
  nixosKeys = lib.attrNames self.nixosConfigurations;
  deployRegistry = [
    (contract "deploy-registry" "flake" (deployNodes == registryDeployable)
      "deploy.nodes ${toString deployNodes} != registry deployable hosts ${toString registryDeployable}"
    )
    (contract "deploy-registry" "flake" (lib.all (h: lib.elem h nixosKeys) deployNodes)
      "deploy nodes missing from nixosConfigurations: ${
        toString (lib.filter (h: !lib.elem h nixosKeys) deployNodes)
      }"
    )
  ];
  # ci/deploy.sh reads one shared SSH port, so assert uniformity here.
  deployPorts = lib.map (h: addresses.hosts.${h}.ssh.listenPort) registryDeployable;
  deploySshPort = contract "deploy-ssh-port" "flake" (
    deployPorts != [ ] && lib.all (p: p == builtins.head deployPorts) deployPorts
  ) "deployable hosts must share one ssh.listenPort: ${toString deployPorts}";

  contractResults =
    fleetBaseline
    ++ sshdHardening
    ++ exporterSourceScope
    ++ deployRegistry
    ++ [
      gateCoverage
      proxyAllowlist
      edgeNoTcp
      deploySshPort
    ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        # A1: SUMMARY.md chapters (including plans) build cleanly via mdbook
        # (internal markdown links would require mdbook-linkcheck).
        docs = pkgs.runCommand "check-docs-build" { } ''
          ${lib.getExe (import ../docs/builder.nix { inherit pkgs; })} ${
            lib.fileset.toSource {
              root = ../docs;
              fileset = lib.fileset.unions [
                ../docs/book.toml
                ../docs/src
              ];
            }
          } "$out"
        '';

        # A3: the ai-gate behavior matrix (modules/services/ssh/scripts/).
        ai-gate = pkgs.runCommand "check-ai-gate" { } ''
          bash ${../modules/services/ssh/scripts/ai-gate-test.sh} ${../modules/services/ssh/scripts/ai-gate.sh}
          touch "$out"
        '';

        # A2/A4: pure-eval config contracts; failures throw above, before this
        # derivation exists. Building it prints the pass lines.
        contracts = pkgs.runCommand "check-config-contracts" { } ''
          printf '%s\n' ${lib.escapeShellArgs contractResults}
          touch "$out"
        '';
      };
    };
}
