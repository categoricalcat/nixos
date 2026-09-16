{ pkgs }:

pkgs.writeShellScriptBin "seenix" ''
      HOST="''${1:-$(hostname)}"
      if [ "$HOST" = "$(hostname)" ] && [ -e /run/current-system ]; then
        TARGET="/run/current-system"
      else
        TARGET=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$HOST.config.system.build.toplevel")
      fi

      JSON=$(mktemp --suffix=-seenix.json)
      trap 'rm -f "$JSON"' EXIT
      nix path-info -r --json "$TARGET" > "$JSON"

      SITE=$(nix build --no-link --print-out-paths github:fzakaria/seenix#site)
      echo "Serving seenix for $HOST on http://127.0.0.1:8138/?json=/closure.json"
      command -v xdg-open >/dev/null 2>&1 && (sleep 0.5 && xdg-open "http://127.0.0.1:8138/?json=/closure.json") &

    exec ${pkgs.python3}/bin/python3 - "$SITE" "$JSON" <<'EOF'
  import http.server, os, sys, urllib.parse

  SITE, JSON = sys.argv[1], sys.argv[2]

  class Handler(http.server.SimpleHTTPRequestHandler):
      def translate_path(self, path):
          p = urllib.parse.urlparse(path).path
          if p == "/closure.json": return JSON
          if p == "/": p = "/index.html"
          return os.path.join(SITE, p.lstrip("/"))
      def end_headers(self):
          self.send_header("Cache-Control", "no-store")
          self.send_header("Access-Control-Allow-Origin", "*")
          super().end_headers()

  http.server.SimpleHTTPRequestHandler.extensions_map.update({".js": "text/javascript", ".wasm": "application/wasm", ".json": "application/json"})
  http.server.ThreadingHTTPServer(("", 8138), Handler).serve_forever()
  EOF
''
