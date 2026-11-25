# Config contracts and repo checks.
#
# Contracts are pure-evaluation security invariants over the declared
# configuration (`self.nixosConfigurations`): they assert current policy,
# never aspiration. Failures throw `contract <name> failed for <host>: <why>`
# at evaluation time, so `nix flake check --no-build` and CI fail early
# without building.
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

  # --- yirukou vhost predicates (proxy-allowlist, auth-gate) ------------------
  edgeVhosts = self.nixosConfigurations.yirukou.config.services.nginx.virtualHosts;
  served =
    loc:
    loc.proxyPass != null
    || loc.root != null
    || loc.alias != null
    || loc.tryFiles != null
    || lib.hasInfix "proxy_pass" loc.extraConfig;
  # Only subrequests reach an internal location; a client gets 404.
  internal = loc: lib.elem "internal;" (lines loc.extraConfig);
  onMtlsListener =
    vhost: builtins.any (l: l.port == addresses.hosts.yirukou.services.ingress.port) vhost.listen;

  # --- proxy-allowlist -------------------------------------------------------
  # Every proxying/file-serving vhost/location enforces restrictedProxyConfig;
  # static `return` test and redirect locations and internal subrequest
  # targets are exempt. The mTLS machine listener is exempt as a whole: its
  # gate is the client certificate, and its location allowlist names the
  # scraper instead of the LAN.
  proxyAllowlist =
    let
      lan = addresses.hosts.yirukou.network.lan;
      expected = [
        "allow ${lan.ipv4.cidr};"
        "allow ${lan.ipv6.cidr};"
        "deny all;"
      ];
      allowDeny = text: lib.filter (l: lib.hasPrefix "allow " l || lib.hasPrefix "deny " l) (lines text);
      violating = lib.concatMap (
        vname:
        let
          vhost = edgeVhosts.${vname};
        in
        if onMtlsListener vhost then
          [ ]
        else
          lib.optional (vhost.root != null && allowDeny vhost.extraConfig != expected) "${vname} (vhost root)"
          ++ lib.concatMap (
            lname:
            let
              loc = vhost.locations.${lname};
            in
            lib.optional (
              served loc && !internal loc && allowDeny loc.extraConfig != expected
            ) "${vname}/${lname}"
          ) (lib.attrNames vhost.locations)
      ) (lib.attrNames edgeVhosts);
    in
    contract "proxy-allowlist" "yirukou" (violating == [ ])
      "locations whose allow/deny sequence is not exactly the registry LAN CIDRs then deny all: ${toString violating}";

  # --- auth-gate -------------------------------------------------------------
  # Every served yirukou location answers only after Authelia, except the
  # named exemptions (machine clients, native apps, the portal).
  # A gate's auth_request target must be an internal location asking the
  # AuthRequest endpoint under the Authelia Host: any other target lets a
  # backend's catch-all 200 admit every request.
  authGate =
    let
      svc = addresses.hosts.yifuwuqi.services;
      exempt = {
        ${svc.attic.domain} = [ "/" ];
        ${svc.authelia.domain} = [ "/" ];
        ${svc.jellyfin.domain} = [ "/" ];
        ${svc.pinepods.domain} = [ "/" ];
        "dns.${addresses.baseDomain}" = [ "/dns-query" ];
      };
      gateTarget =
        text:
        lib.mapNullable (l: lib.removeSuffix ";" (lib.removePrefix "auth_request " l)) (
          lib.findFirst (lib.hasPrefix "auth_request ") null (lines text)
        );
      endpointValid =
        vhost: target:
        let
          loc = vhost.locations."= ${target}" or null;
        in
        loc != null
        && internal loc
        && lib.hasSuffix "/api/authz/auth-request" (toString loc.proxyPass)
        && lib.elem "proxy_set_header Host ${svc.authelia.domain};" (lines loc.extraConfig);
      # Grafana's auth.proxy is the only login it has left, so a gated location
      # that forgets the header authenticates nobody and cannot be fixed by
      # logging in: pin the propagation, not just the subrequest.
      identityForwarded =
        loc: lib.elem "proxy_set_header Remote-User $authelia_user;" (lines loc.extraConfig);
      locationIssues =
        vname: vhost: lname:
        let
          loc = vhost.locations.${lname};
          target = gateTarget loc.extraConfig;
        in
        if !served loc || internal loc || lib.elem lname (exempt.${vname} or [ ]) then
          [ ]
        else if target == null then
          [ "${vname}/${lname} is ungated" ]
        else
          lib.optional (!endpointValid vhost target) "${vname}/${lname} gates through invalid ${target}"
          ++ lib.optional (!identityForwarded loc) "${vname}/${lname} drops the identity header";
      violating = lib.concatMap (
        vname:
        let
          vhost = edgeVhosts.${vname};
        in
        if onMtlsListener vhost then
          [ ]
        else
          lib.optional (vhost.root != null) "${vname} serves a vhost root outside any gated location"
          ++ lib.concatMap (locationIssues vname vhost) (lib.attrNames vhost.locations)
      ) (lib.attrNames edgeVhosts);
      stale = lib.concatLists (
        lib.mapAttrsToList (
          vname: lnames:
          lib.optional (
            !(edgeVhosts ? ${vname}) || !lib.all (l: edgeVhosts.${vname}.locations ? ${l}) lnames
          ) "exemption ${vname} ${toString lnames} matches no location"
        ) exempt
      );
    in
    contractIssues "auth-gate" "yirukou" (violating ++ stale);

  # --- vhost-naming ----------------------------------------------------------
  # A service's hostname is its registry key, `<key>.<baseDomain>`: the gate,
  # its exemptions and every client URI key off that one name.
  vhostNaming = contractIssues "vhost-naming" "registry" (
    lib.concatLists (
      lib.mapAttrsToList (
        host: h:
        lib.mapAttrsToList (key: s: "${host}.${key} is ${s.domain}") (
          lib.filterAttrs (key: s: s ? domain && s.domain != "${key}.${addresses.baseDomain}") (
            h.services or { }
          )
        )
      ) addresses.hosts
    )
  );

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

  # --- container-identity -----------------------------------------------------
  # Container identity policy: one principal per ID. Every declared container
  # either runs as a numeric identity (user uid:gid or PUID/PGID) pinned in
  # 330-399 on a declared account and group, unique per container, or records
  # why its host-root processes are allowed (rootReason; dual-process images
  # like s6-overlay may carry both). New container accounts continue from 348;
  # the block sits below the dynamic allocator (400-999) and cannot collide.
  containerIdentity =
    let
      parseIdentity = import ../modules/virtualisation/container-identity.nix { inherit lib; };
    in
    lib.map (
      host:
      let
        cfg = self.nixosConfigurations.${host}.config;
        containers = cfg.virtualisation.oci-containers.containers;
        pinnedUids = lib.pipe cfg.users.users [
          (lib.filterAttrs (_: u: u.uid != null && u.uid >= 330 && u.uid <= 399))
          (lib.mapAttrsToList (_: u: u.uid))
        ];
        pinnedGids = lib.pipe cfg.users.groups [
          (lib.filterAttrs (_: g: g.gid != null && g.gid >= 330 && g.gid <= 399))
          (lib.mapAttrsToList (_: g: g.gid))
        ];
        identities = lib.mapAttrs (_: parseIdentity) containers;
        perContainerIssues =
          name: id:
          let
            hasId = id.uid != null && id.gid != null;
            partialId = (id.uid != null) != (id.gid != null);
          in
          lib.optional partialId "${name}: partial numeric identity (uid=${toString id.uid}, gid=${toString id.gid})"
          ++ lib.optional (
            !partialId && !hasId && id.rootReason == null
          ) "${name}: no numeric user/PUID/PGID and no rootReason"
          ++ lib.optionals hasId (
            lib.optional (
              !lib.elem id.uid pinnedUids
            ) "${name}: uid ${toString id.uid} is not a pinned account uid in 330-399"
            ++ lib.optional (
              !lib.elem id.gid pinnedGids
            ) "${name}: gid ${toString id.gid} is not a pinned group gid in 330-399"
          );
        duplicateUids = lib.filterAttrs (_: names: lib.length names > 1) (
          lib.groupBy (name: toString identities.${name}.uid) (
            lib.filter (name: identities.${name}.uid != null) (lib.attrNames identities)
          )
        );
        dupIssues = lib.mapAttrsToList (
          uid: names: "uid ${uid} shared by containers: ${lib.concatStringsSep ", " names}"
        ) duplicateUids;
      in
      contractIssues "container-identity" host (
        lib.concatLists (lib.mapAttrsToList perContainerIssues identities) ++ dupIssues
      )
    ) (lib.attrNames self.nixosConfigurations);

  # --- hardening-baseline -----------------------------------------------------
  # Custom long-running units (inventory in modules/hardening.nix) either
  # satisfy every baseline key (scalars equal it, so a stricter scalar is still
  # flagged; RestrictAddressFamilies may be a subset; SystemCallFilter may only
  # append `~` deny groups), carry `minus` with the exact keys they drop/weaken,
  # or are exempt with a reason.
  # Upstream-hardened units are deliberately outside the inventory: this
  # contract guards our attrset spreads, not upstream hardening.
  hardeningBaseline =
    let
      hardening = import ../modules/hardening.nix;
      inherit (hardening) baseline;
      baselineKeys = lib.attrNames baseline;
      satisfies =
        sc: k:
        let
          b = baseline.${k};
          v = sc.${k};
        in
        builtins.hasAttr k sc
        && (
          v == b
          || (k == "RestrictAddressFamilies" && builtins.isList v && lib.all (af: lib.elem af b) v)
          || (
            k == "SystemCallFilter"
            && builtins.isList v
            && lib.take (lib.length b) v == b
            && lib.all (lib.hasPrefix "~") (lib.drop (lib.length b) v)
          )
        );
      unitIssues =
        cfg: unit: spec:
        if !builtins.hasAttr unit cfg.systemd.services then
          [ "${unit}: inventoried but not defined on this host" ]
        else if spec ? exempt then
          [ ]
        else
          let
            sc = cfg.systemd.services.${unit}.serviceConfig;
            minus = spec.minus or [ ];
            unknown = lib.filter (k: !builtins.hasAttr k baseline) minus;
            stale = lib.filter (k: builtins.hasAttr k baseline && satisfies sc k) minus;
            violated = lib.filter (k: !satisfies sc k) (lib.subtractLists minus baselineKeys);
          in
          lib.optional (unknown != [ ]) "${unit}: unknown minus keys ${toString unknown}"
          ++ lib.optional (stale != [ ]) "${unit}: minus keys already satisfy baseline ${toString stale}"
          ++ lib.optional (violated != [ ]) "${unit}: missing or weakened baseline keys ${toString violated}";
      hostIssues =
        host:
        let
          cfg = self.nixosConfigurations.${host}.config;
        in
        lib.concatLists (lib.mapAttrsToList (unitIssues cfg) hardening.units.${host});
    in
    lib.map (host: contractIssues "hardening-baseline" host (hostIssues host)) (
      lib.attrNames hardening.units
    );

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

  # Exporter matrix for the generated monitoring fragment: which registry
  # exporter is enabled on which scrape host, with the evaluated port
  # (exporter ports come from module defaults, not the registry).
  exporterMatrix =
    let
      names = lib.attrNames addresses.monitoring.exporters;
      hosts = addresses.monitoring.scrapeHosts;
    in
    lib.genAttrs names (
      name:
      let
        exporterOn = h: self.nixosConfigurations.${h}.config.services.prometheus.exporters.${name};
        hs = lib.filter (h: (exporterOn h).enable) hosts;
        ports = lib.unique (map (h: (exporterOn h).port) hs);
      in
      {
        hosts = hs;
        # The fragment renders one port per exporter, so diverging per-host
        # ports fail here instead of rendering the first host's value.
        port =
          if ports == [ ] then
            null
          else if lib.length ports == 1 then
            builtins.head ports
          else
            throw "exporter ${name}: ports differ across hosts (${toString ports}); docs/generate.nix renders one port per exporter";
      }
    );

  # Registry-derived mdbook fragments (docs/src/generated/), rendered by
  # docs/generate.nix. Committed fragments must match this derivation; the
  # docs-registry-sync check fails on drift.
  docsFragments = import ../docs/generate.nix {
    inherit lib addresses exporterMatrix;
  };

  contractResults =
    fleetBaseline
    ++ sshdHardening
    ++ containerIdentity
    ++ hardeningBaseline
    ++ deployRegistry
    ++ [
      gateCoverage
      proxyAllowlist
      authGate
      vhostNaming
      edgeNoTcp
      deploySshPort
    ];
in
{
  perSystem =
    { pkgs, ... }:
    let
      docsFragmentsDrv = pkgs.linkFarm "docs-registry-fragments" (
        lib.mapAttrsToList (name: text: {
          inherit name;
          path = pkgs.writeText name text;
        }) docsFragments
      );
    in
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

        sillytavern-settings-overlay =
          let
            yifuwuqiSt = self.nixosConfigurations.yifuwuqi;
            stDefaultSettings = "${yifuwuqiSt.pkgs.sillytavern}/lib/node_modules/sillytavern/default/content/settings.json";
            inherit (yifuwuqiSt.config.yi.services.sillytavern) settingsOverlay;
          in
          pkgs.runCommand "check-sillytavern-settings-overlay"
            {
              nativeBuildInputs = [
                pkgs.diffutils
                pkgs.jq
              ];
            }
            ''
              bash ${../modules/services/ai/sillytavern-settings-overlay-test.sh} \
                ${lib.getExe settingsOverlay.package} \
                ${stDefaultSettings} \
                ${settingsOverlay.file}
              touch "$out"
            '';

        # A2/A4: pure-eval config contracts; failures throw above, before this
        # derivation exists. Building it prints the pass lines.
        contracts = pkgs.runCommand "check-config-contracts" { } ''
          printf '%s\n' ${lib.escapeShellArgs contractResults}
          touch "$out"
        '';

        # Registry-derived doc fragments must match the committed tree:
        # render, then fail on any diff (fail-on-change, like treefmt).
        docs-registry-sync = pkgs.runCommand "check-docs-registry-sync" { } ''
          diff -r ${docsFragmentsDrv} ${../docs/src/generated}
          touch "$out"
        '';
      };

      packages = {
        # Refresh with: nix build .#docs-generated --out-link /tmp/docs-frag
        #   install -m 0644 /tmp/docs-frag/*.md docs/src/generated/
        docs-generated = docsFragmentsDrv;
      };
    };
}
