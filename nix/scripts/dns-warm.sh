#!/usr/bin/env bash
set -euo pipefail

# Examples:
#   dns-warm -r 127.0.0.1:5335                   # warm top 100k ranked (default)
#   dns-warm 1000 -r 10.42.0.2:5335 -retry 3     # warm top 1k with 3 retries

COUNT=100000
if [[ -n "${1:-}" && "$1" != -* ]]; then
  COUNT="$1"
  shift
fi

if [[ " $* " != *" -r "* && " $* " != *" -resolver "* ]]; then
  echo "usage: dns-warm [COUNT] -r HOST [dnsx flags...]" >&2
  exit 1
fi

list=$(mktemp)
trap 'rm -f "$list" resume.cfg' EXIT
curl -sL https://downloads.majestic.com/majestic_million.csv \
  | awk -F',' 'NR>1 {print NR-1 "\t" $3}' \
  | head -n "$COUNT" > "$list" || true
[[ -s "$list" ]] || { echo "error: failed to fetch domain list" >&2; exit 1; }
cut -f2 "$list" \
  | dnsx -silent "$@" \
  | awk 'NR==FNR { rank[$2]=$1; next } { key=$1; if (key in rank) print rank[key] "\t" $0 }' "$list" - \
  | sort -n \
  | cut -f2-
