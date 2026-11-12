#!/usr/bin/env bash
set -euo pipefail

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fluxer"
app_image="$data_dir/Fluxer.AppImage"
system="@system@"
mkdir -p "$data_dir"

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

meta_url="https://pkgs.fluxer.com/desktop/stable/linux/$arch/latest"
app_url="https://pkgs.fluxer.com/desktop/stable/linux/$arch/latest/appimage"

file_sha() {
  "@coreutils@/sha256sum" "$1" | "@coreutils@/cut" -d ' ' -f 1
}

# Refresh the shell before Fluxer starts. The in-app updater blocks forever
# when this file is older than the published build.
sync_appimage() {
  local force="${1:-}"
  local remote sha tmp got

  if ! remote="$("@curl@" --http1.1 -fsSL --max-time 8 --connect-timeout 5 \
    --retry 3 --retry-all-errors \
    "$meta_url" | "@jq@" -r '.files.appimage.sha256 // empty')"; then
    echo "Could not read the Fluxer release manifest." >&2
    return 1
  fi
  if [[ ! $remote =~ ^[0-9a-f]{64}$ ]]; then
    echo "Fluxer release manifest has no AppImage checksum." >&2
    return 1
  fi

  # Called from `if`, so a failing command here does not abort the function.
  if [[ $force != force && -f $app_image ]]; then
    sha="$(file_sha "$app_image")" || return 1
    if [[ $sha == "$remote" ]]; then
      return 0
    fi
  fi

  tmp="$app_image.tmp.$$"
  echo "Downloading Fluxer AppImage..." >&2
  if ! "@curl@" --http1.1 -fSL --retry 3 --retry-all-errors --retry-delay 2 \
    --connect-timeout 15 --speed-time 30 --speed-limit 1000 \
    --progress-bar "$app_url" -o "$tmp"; then
    echo "Failed to download Fluxer AppImage from $app_url" >&2
    rm -f "$tmp"
    return 1
  fi

  got="$(file_sha "$tmp")" || {
    rm -f "$tmp"
    return 1
  }
  if [[ $got != "$remote" ]]; then
    echo "Fluxer checksum mismatch: expected $remote, got $got" >&2
    rm -f "$tmp"
    return 1
  fi

  if ! chmod +x "$tmp" || ! mv "$tmp" "$app_image"; then
    rm -f "$tmp"
    echo "Failed to install Fluxer AppImage." >&2
    return 1
  fi
  echo "Fluxer AppImage updated at $app_image" >&2
}

if [[ ${1:-} == "--update-fluxer-binary" ]]; then
  sync_appimage force
  exit 0
fi

# --fluxer-update on an outdated shell is the splash that never returns.
# Module updates still run once the downloaded file matches upstream.
shell_current=0
if sync_appimage; then
  shell_current=1
elif [[ ! -f $app_image ]]; then
  exit 1
else
  echo "Fluxer shell update failed. Opening the installed build." >&2
fi

flags=()
if [[ $shell_current == 1 ]]; then
  flags+=("--fluxer-update")
fi
flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/fluxer-flags.conf"
fallback_flags_file="$HOME/.var/app/app.fluxer.Fluxer/config/fluxer-flags.conf"

target_flags=""
if [[ -f $flags_file ]]; then
  target_flags="$flags_file"
elif [[ -f $fallback_flags_file ]]; then
  target_flags="$fallback_flags_file"
fi

if [[ $target_flags != "" ]]; then
  while IFS= read -r line || [[ $line != "" ]]; do
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z $line || $line =~ ^# ]] && continue
    flags+=("$line")
  done <"$target_flags"
fi

exec "@appimageRun@" "$app_image" "${flags[@]}" "$@"
