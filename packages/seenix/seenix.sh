# shellcheck shell=bash
# Path to serve.py, injected via writeShellApplication runtimeEnv.
SEENIX_SERVE_PY="${SEENIX_SERVE_PY:?runtimeEnv injection missing}"
host="${1:-}"
[ "$host" != "" ] || host=$(hostname)
if [ "$host" = "$(hostname)" ] && [ -e /run/current-system ]; then
  target="/run/current-system"
else
  target=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$host.config.system.build.toplevel")
fi

json=$(mktemp --suffix=-seenix.json)
# Covers failures before exec; after exec the Python atexit owns cleanup.
trap 'rm -f "$json"' EXIT
nix path-info -r --json --json-format 1 "$target" >"$json"

site=$(nix build --no-link --print-out-paths "github:fzakaria/seenix#site")
url="http://127.0.0.1:8138/?json=/closure.json"
echo "Serving seenix for $host on $url"
if command -v xdg-open >/dev/null 2>&1; then
  (sleep 1 && xdg-open "$url") &
fi
exec python3 "$SEENIX_SERVE_PY" "$site" "$json"
