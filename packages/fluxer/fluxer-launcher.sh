#!/usr/bin/env bash
set -euo pipefail

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fluxer"
app_image="$data_dir/Fluxer.AppImage"
system="@system@"
mkdir -p "$data_dir"

download_appimage() {
  case "$system" in
  x86_64-linux) arch="x64" ;;
  aarch64-linux) arch="arm64" ;;
  *)
    case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64) arch="arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
    esac
    ;;
  esac

  url="https://pkgs.fluxer.com/desktop/stable/linux/$arch/latest/appimage"
  tmp="$app_image.tmp.$$"

  echo "Downloading latest Fluxer AppImage..." >&2
  if ! @curl@ -fSL --progress-bar "$url" -o "$tmp"; then
    echo "Failed to download Fluxer AppImage from $url" >&2
    rm -f "$tmp"
    exit 1
  fi

  chmod +x "$tmp"
  mv "$tmp" "$app_image"
  echo "Fluxer AppImage downloaded to $app_image" >&2
}

if [ "${1:-}" = "--update-fluxer-binary" ]; then
  download_appimage
  exit 0
fi

if [ ! -f "$app_image" ]; then
  download_appimage
fi

# Load user-configured runtime flags
flags=()
flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/fluxer-flags.conf"
fallback_flags_file="$HOME/.var/app/app.fluxer.Fluxer/config/fluxer-flags.conf"

target_flags=""
if [ -f "$flags_file" ]; then
  target_flags="$flags_file"
elif [ -f "$fallback_flags_file" ]; then
  target_flags="$fallback_flags_file"
fi

if [ "$target_flags" != "" ]; then
  while IFS= read -r line || [ "$line" != "" ]; do
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z $line || $line =~ ^# ]] && continue
    flags+=("$line")
  done <"$target_flags"
fi

exec @appimageRun@ "$app_image" "${flags[@]}" "$@"
