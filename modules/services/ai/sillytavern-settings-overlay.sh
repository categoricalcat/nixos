#!/usr/bin/env bash
# Idempotently overlay Nix-owned SillyTavern settings onto a mutable
# settings.json without clobbering unrelated user settings or user profiles.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  printf 'usage: %s <target-settings.json> <default-settings.json> <overlay.json>\n' "$0" >&2
  exit 2
fi

target="$1"
default_file="$2"
overlay_file="$3"

target_dir="$(dirname "$target")"
install -d -m 0700 "$target_dir"

if [ -e "$target" ]; then
  if ! jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
    printf 'sillytavern-settings-overlay: refusing to overwrite invalid JSON object in %s\n' "$target" >&2
    exit 1
  fi
  base_file="$target"
else
  base_file="$default_file"
fi

tmp_file=""
cleanup() {
  if [ "$tmp_file" != "" ] && [ -e "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

tmp_file="$(mktemp "${target_dir}/.settings.json.XXXXXX")"
chmod 0600 "$tmp_file"

jq --slurpfile overlay "$overlay_file" '
  ($overlay[0]) as $o
  | ($o.extension_settings.connectionManager.profiles // []) as $rawNixProfiles
  | ($rawNixProfiles | map(del(.contextLength))) as $nixProfiles
  | ($o.extension_settings.connectionManager.selectedProfile // null) as $defaultSelected
  | ((.extension_settings.connectionManager.profiles // [])
      | map(select(((.id? // "") | tostring | startswith("nix:")) | not))) as $userProfiles
  | ($nixProfiles + $userProfiles) as $nextProfiles
  | ($nextProfiles | map(.id)) as $validIds
  | (.extension_settings.connectionManager.selectedProfile // null) as $currentSelected
  | (if ($currentSelected != null and $currentSelected != "" and (($validIds | index($currentSelected)) != null)) then
       $currentSelected
     else
       $defaultSelected
     end) as $nextSelected
  | ($rawNixProfiles | map(select(.id == $nextSelected)) | .[0] // null) as $activeNix
  | ($o
      | del(.extension_settings.connectionManager)
      | if $activeNix != null then
          .oai_settings = ((.oai_settings // {}) + {
            chat_completion_source: ($activeNix.api // .oai_settings.chat_completion_source),
            custom_url: ($activeNix."api-url" // .oai_settings.custom_url),
            custom_model: ($activeNix.model // .oai_settings.custom_model),
            openai_max_context: ($activeNix.contextLength // .oai_settings.openai_max_context)
          })
        else
          del(
            .main_api,
            .oai_settings.chat_completion_source,
            .oai_settings.custom_url,
            .oai_settings.custom_model,
            .oai_settings.openai_max_context
          )
        end) as $scalarOverlay
  | (. * $scalarOverlay)
  | .extension_settings.connectionManager = (
      (.extension_settings.connectionManager // {})
      + {
          profiles: $nextProfiles,
          selectedProfile: $nextSelected
        }
    )
' "$base_file" >"$tmp_file"

mv -f "$tmp_file" "$target"
tmp_file=""
