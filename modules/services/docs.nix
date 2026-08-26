{
  pkgs,
  addresses,
  ...
}:

let
  buildDocs = pkgs.writeShellScript "build-fleet-docs" ''
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -r /var/lib/fleet-docs/src/. "$tmp/"
    chmod -R u+w "$tmp"
    rm -rf "$tmp/book" "$tmp/.git"
    echo -e "\n# Architecture Plans & RFCs\n\n- [Architecture Plans]()" >> "$tmp/src/SUMMARY.md"
    for p in "$tmp"/src/plans/*.md; do
      [ -f "$p" ] || continue
      case "$(basename "$p")" in .*|*~|*.tmp|*.bak|'#*'|_*) continue ;; esac
      t=$(sed -n 's/^# //p' "$p" | head -n1 | tr -d '\r' | sed 's/\[/\\[/g; s/\]/\\]/g' | xargs)
      echo "  - [''${t:-$(basename "$p" .md)}](plans/$(basename "$p"))" >> "$tmp/src/SUMMARY.md"
    done
    ${pkgs.mdbook}/bin/mdbook build "$tmp" -d "$tmp/book" >/dev/null && \
      mkdir -p /var/lib/fleet-docs/book && \
      ${pkgs.rsync}/bin/rsync -r --delete --no-owner --no-group "$tmp/book/" /var/lib/fleet-docs/book/
  '';

  commonHardening = {
    User = "docs";
    Group = "docs";
    ProtectHome = true;
    ProtectSystem = "strict";
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectProc = "invisible";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    ReadWritePaths = [ "/var/lib/fleet-docs" ];
    SystemCallErrorNumber = "EPERM";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
in
{
  users.users.docs = {
    isSystemUser = true;
    group = "docs";
  };
  users.groups.docs = { };

  fileSystems."/var/lib/fleet-docs/src" = {
    device = "/home/yi/the.files/nixos/docs";
    fsType = "none";
    options = [
      "bind"
      "ro"
    ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/fleet-docs 0755 docs docs -"
      "d /var/lib/fleet-docs/src 0755 root root -"
      "d /var/lib/fleet-docs/book 0755 docs docs -"
    ];

    services = {
      docs = {
        description = "Fleet Documentation HTTP Server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        unitConfig.RequiresMountsFor = [ "/var/lib/fleet-docs/src" ];
        preStart = "${buildDocs}";
        serviceConfig = commonHardening // {
          ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd /var/lib/fleet-docs/book --port ${toString addresses.services.docs.port} --addr 0.0.0.0 --no-listing --no-server-id --hide-dotfiles";
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          Restart = "always";
        };
      };

      docs-watcher = {
        description = "Fleet Documentation Real-Time Watcher";
        wantedBy = [ "multi-user.target" ];
        after = [ "docs.service" ];
        wants = [ "docs.service" ];
        unitConfig.RequiresMountsFor = [ "/var/lib/fleet-docs/src" ];
        serviceConfig = commonHardening // {
          ExecStart = "${pkgs.watchexec}/bin/watchexec -w /var/lib/fleet-docs/src --debounce 1500ms --restart -- ${buildDocs}";
          Restart = "always";
        };
      };
    };
  };
}
