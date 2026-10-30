{
  pkgs ? import <nixpkgs> { },
}:
let
  buildDocs = pkgs.writeShellScriptBin "docs-build" ''
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -r . "$tmp/"
    chmod -R u+w "$tmp"
    rm -rf "$tmp/book"

    echo -e "\n# Architecture Plans & RFCs\n\n- [Architecture Plans]()" >> "$tmp/src/SUMMARY.md"
    for p in "$tmp"/src/plans/*.md; do
      [ -f "$p" ] || continue
      case "$(basename "$p")" in .*|*~|*.tmp|*.bak|'#*'|_*) continue ;; esac
      t=$(sed -n 's/^# //p' "$p" | head -n1 | tr -d '\r' | sed 's/\[/\\[/g; s/\]/\\]/g' | xargs)
      echo "  - [''${t:-$(basename "$p" .md)}](plans/$(basename "$p"))" >> "$tmp/src/SUMMARY.md"
    done

    ${pkgs.mdbook-mermaid}/bin/mdbook-mermaid install "$tmp"
    mkdir -p book
    ${pkgs.mdbook}/bin/mdbook build "$tmp" -d "$PWD/book"
    echo "Book built successfully in $PWD/book"
  '';

  serveDocs = pkgs.writeShellScriptBin "docs-serve" ''
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -r . "$tmp/"
    chmod -R u+w "$tmp"
    rm -rf "$tmp/book"

    echo -e "\n# Architecture Plans & RFCs\n\n- [Architecture Plans]()" >> "$tmp/src/SUMMARY.md"
    for p in "$tmp"/src/plans/*.md; do
      [ -f "$p" ] || continue
      case "$(basename "$p")" in .*|*~|*.tmp|*.bak|'#*'|_*) continue ;; esac
      t=$(sed -n 's/^# //p' "$p" | head -n1 | tr -d '\r' | sed 's/\[/\\[/g; s/\]/\\]/g' | xargs)
      echo "  - [''${t:-$(basename "$p" .md)}](plans/$(basename "$p"))" >> "$tmp/src/SUMMARY.md"
    done

    ${pkgs.mdbook-mermaid}/bin/mdbook-mermaid install "$tmp"
    exec ${pkgs.mdbook}/bin/mdbook serve "$tmp" "$@"
  '';
in
pkgs.mkShell {
  packages = [
    pkgs.mdbook
    pkgs.mdbook-mermaid
    buildDocs
    serveDocs
  ];
}
