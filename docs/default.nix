{
  pkgs ? import <nixpkgs> { },
}:
pkgs.stdenv.mkDerivation {
  pname = "gang-docs";
  version = "unstable";
  src = ./.;

  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.gnused
    pkgs.findutils
    pkgs.mdbook
    pkgs.mdbook-mermaid
  ];

  buildPhase = ''
    runHook preBuild

    tmp="$(mktemp -d)"
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

    mdbook-mermaid install "$tmp"
    mdbook build "$tmp" -d "$out"

    runHook postBuild
  '';
}
