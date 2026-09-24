# shellcheck shell=bash
dir="$(mktemp -d -t shot-XXXXXX)"
trap 'rm -rf "$dir"' EXIT

raw="$dir/raw.png"
sdr="$dir/sdr.png"

output=""
args=()

case "${1:-area}" in
area)
  slurp_out=$(slurp -b "#00000080" -c "#ffffff80" -f "%x,%y %wx%h %o" 2>/dev/null) || exit 0
  [ "$slurp_out" != "" ] || exit 0
  read -r pos dim output <<<"$slurp_out"
  args+=(-g "$pos $dim")
  ;;
window)
  if ! win=$(mmsg get focusing-client 2>/dev/null); then
    echo "shot: no focused window found" >&2
    exit 1
  fi
  read -r pos dim output < <(
    jq -r '"\(.x),\(.y) \(.width)x\(.height) " + (if .monitor | type == "object" then .monitor.name else (.monitor // "") end)' <<<"$win"
  )
  [ "$pos" != "" ] || exit 1
  args+=(-g "$pos $dim")
  ;;
full)
  output=$(mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]? | select(.active) | .name' || true)
  [ "$output" != "" ] && args+=(-o "$output")
  ;;
*)
  echo "Usage: shot [area|window|full]" >&2
  exit 1
  ;;
esac

grim "${args[@]}" "$raw"

target="$raw"
if [ "$output" != "" ] && [ "$(mmsg get monitor "$output" 2>/dev/null | jq -r '.is_hdr // false')" = "true" ]; then
  if ffmpeg -y -v error -i "$raw" -vf "zscale=tin=smpte2084:pin=bt2020:t=iec61966-2-1:p=bt709:npl=190" "$sdr"; then
    target="$sdr"
  else
    echo "shot: HDR-to-SDR conversion failed, falling back to raw capture" >&2
  fi
fi

ksnip "$target"
