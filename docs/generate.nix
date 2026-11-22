# Renders registry-derived reference tables into the mdbook fragments under
# docs/src/generated/. Committed fragments are the rendered source of truth;
# the docs-registry-sync check (nix/checks.nix) re-renders and fails on drift,
# so a registry edit without a doc refresh breaks CI instead of quietly
# becoming historical fiction. Edit the registry, not the fragments.
#
# Data sources: `addresses` is modules/addresses.nix; `exporterMatrix` is
# derived in nix/checks.nix from the evaluated host configs (exporter ports
# come from module defaults, not the registry). Per-host interface tables and
# networking-page matrices stay manual prose for now.
{
  lib,
  addresses,
  exporterMatrix,
}:
let
  dash = "—";
  fmtPort = p: if p == null then dash else toString p;

  hostRow =
    name: h:
    "| ${name}"
    + " | ${h.network.lan.ipv4.host or dash}"
    + " | ${h.network.lan.ipv6.host or dash}"
    + " | ${h.network.tailscale.ipv4.host or dash}"
    + " | ${fmtPort (h.ssh.listenPort or null)}"
    + " | ${if h.deploy or false then "yes" else "no"}"
    + " |";

  serviceRow =
    host: name: s:
    "| ${host} | ${name} | ${s.domain or dash} | ${fmtPort (s.port or s.httpPort or null)} |";

  exporterRow =
    name: spec:
    "| ${name} | ${fmtPort spec.port} | ${
      if spec.hosts == [ ] then dash else lib.concatStringsSep ", " spec.hosts
    } |";

  mon = addresses.monitoring;
in
{
  "hosts.md" = ''
    <!-- Generated from modules/addresses.nix by docs/generate.nix (flake package docs-generated); edit the registry, not this file. -->

    | Host | LAN (v4) | LAN (ULA v6) | Tailnet (v4) | SSH port | deploy-rs |
    | --- | --- | --- | --- | --- | --- |
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList hostRow addresses.hosts)}
  '';

  "services.md" = ''
    <!-- Generated from modules/addresses.nix by docs/generate.nix (flake package docs-generated); edit the registry, not this file. -->

    | Host | Service | Domain | Port |
    | --- | --- | --- | --- |
    ${lib.concatStringsSep "\n" (
      lib.concatLists (
        lib.mapAttrsToList (
          host: h: lib.mapAttrsToList (serviceRow host) (h.services or { })
        ) addresses.hosts
      )
    )}
  '';

  "monitoring.md" = ''
    <!-- Generated from modules/addresses.nix and the evaluated exporter config by docs/generate.nix (flake package docs-generated); edit the registry, not this file. -->

    Central host: **${mon.centralHost}** · Scrape hosts: ${lib.concatStringsSep ", " mon.scrapeHosts} · Log hosts: ${lib.concatStringsSep ", " mon.logHosts}

    | Exporter | Port | Enabled on |
    | --- | --- | --- |
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList exporterRow exporterMatrix)}
  '';
}
