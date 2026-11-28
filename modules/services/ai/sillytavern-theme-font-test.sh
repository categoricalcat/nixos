#!/usr/bin/env bash
# Splice tests for sillytavern-theme-font.sh.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'usage: %s <theme-font-bin>\n' "$0" >&2
  exit 2
fi

bin="$1"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

css="${work_dir}/_css/user.css"
block_one="${work_dir}/block-one.css"
block_two="${work_dir}/block-two.css"

cat >"$block_one" <<'EOF'
/* nix-theme:start */
@font-face { font-family: "One"; }
/* nix-theme:end */
EOF

cat >"$block_two" <<'EOF'
/* nix-theme:start */
@font-face { font-family: "Two"; }
/* nix-theme:end */
EOF

"$bin" "$css" "$block_one"

[ "$(stat -c '%a' "${work_dir}/_css")" = "700" ]
[ "$(stat -c '%a' "$css")" = "600" ]
grep -F 'font-family: "One"' "$css" >/dev/null
grep -F '/* Put custom styles here. */' "$css" >/dev/null
[ "$(grep -c 'nix-theme:start' "$css" || true)" = "1" ]

printf 'body { color: red; }\n' >>"$css"
"$bin" "$css" "$block_one"
grep -F 'body { color: red; }' "$css" >/dev/null
grep -F '/* Put custom styles here. */' "$css" >/dev/null
[ "$(grep -c 'nix-theme:start' "$css" || true)" = "1" ]

cp "$css" "${work_dir}/snapshot.css"
"$bin" "$css" "$block_one"
diff -u "${work_dir}/snapshot.css" "$css"

"$bin" "$css" "$block_two"
grep -F 'font-family: "Two"' "$css" >/dev/null
if grep -F 'font-family: "One"' "$css" >/dev/null; then
  printf 'FAIL: previous theme-font block still present\n' >&2
  exit 1
fi
grep -F 'body { color: red; }' "$css" >/dev/null
[ "$(grep -c 'nix-theme:start' "$css" || true)" = "1" ]
