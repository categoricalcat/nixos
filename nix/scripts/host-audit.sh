#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${1:-all}"
FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ "$TARGET_HOST" = "all" ]; then
  nix eval --impure --json --expr "
  let
    flake = builtins.getFlake \"$FLAKE_DIR\";
    hosts = [ \"yirukou\" \"yifuwuqi\" \"yitaishi\" \"yixiaoqing\" \"yichuang\" ];
  in
  builtins.listToAttrs (map (h: {
    name = h;
    value = {
      services = builtins.attrNames (builtins.removeAttrs flake.nixosConfigurations.\${h}.config.systemd.services [ ]);
      packages = map (p: p.pname or p.name) flake.nixosConfigurations.\${h}.config.environment.systemPackages;
    };
  }) hosts)
  " | jq .
else
  nix eval --impure --json --expr "
  let
    flake = builtins.getFlake \"$FLAKE_DIR\";
    cfg = flake.nixosConfigurations.\"$TARGET_HOST\".config;
  in
  {
    services = builtins.attrNames (builtins.removeAttrs cfg.systemd.services [ ]);
    packages = map (p: p.pname or p.name) cfg.environment.systemPackages;
  }
  " | jq .
fi
