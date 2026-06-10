#!/usr/bin/env bash
TARGET_HOST="${1:-$HOST}"

exec nix repl --expr "(builtins.getFlake (toString ./.)).nixosConfigurations.\"$TARGET_HOST\".config"
