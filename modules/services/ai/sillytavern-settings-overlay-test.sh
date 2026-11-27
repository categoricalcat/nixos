#!/usr/bin/env bash
# Property and failure-mode tests for sillytavern-settings-overlay.sh against
# the evaluated Nix overlay and upstream default settings.json.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  printf 'usage: %s <overlay-bin> <default-settings.json> <nix-overlay.json>\n' "$0" >&2
  exit 2
fi

overlay_bin="$1"
default_file="$2"
overlay_json="$3"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

target="${work_dir}/state/default-user/settings.json"

assert_jq() {
  local expr="$1"
  local file="$2"
  local msg="$3"
  if ! jq -e --slurpfile overlay "$overlay_json" "$expr" "$file" >/dev/null; then
    printf 'FAIL: %s\n' "$msg" >&2
    exit 1
  fi
}

assert_idempotent() {
  local snapshot="${work_dir}/idempotent.json"
  cp "$target" "$snapshot"
  "$overlay_bin" "$target" "$default_file" "$overlay_json"
  diff -u "$snapshot" "$target"
}

# 1. Initial seed from upstream default settings + expected defaults & permissions.
"$overlay_bin" "$target" "$default_file" "$overlay_json"

[ "$(stat -c '%a' "${work_dir}/state/default-user")" = "700" ]
[ "$(stat -c '%a' "$target")" = "600" ]

assert_jq '
  ($overlay[0]) as $expected
  | .main_api == "openai"
  and (has("seedPowerUser") | not)
  and (.oai_settings | contains($expected.oai_settings))
  and (.power_user | contains($expected.seedPowerUser))
' "$target" "initial seed missed expected oai_settings, power_user RP defaults, or upstream defaults"

assert_jq '
  ($overlay[0].extension_settings.sd) as $expected
  | (.extension_settings.sd | contains($expected))
  and (.extension_settings.sd.prompts["0"] | type == "string")
' "$target" "initial seed missed expected sd settings or upstream prompts"

assert_jq '
  ($overlay[0].extension_settings.connectionManager) as $expected
  | .extension_settings.connectionManager.selectedProfile
      == $expected.selectedProfile
  and (.extension_settings.connectionManager.profiles | length > 0)
  and (.extension_settings.connectionManager.profiles
      == ($expected.profiles | map(del(.contextLength, .oaiSettings, .reasoningSettings))))
' "$target" "initial connectionManager profiles/selectedProfile mismatch"

# 2. Idempotence on default Nix profile: f(f(S)) == f(S).
assert_idempotent

# 3. Preserve user profile, user endpoint/samplers/power_user edits, unrelated keys, and GC stale nix:*.
jq '
  .customUserPref = "keep-me"
  | .power_user.default_persona = "persona.png"
  | .power_user.reasoning.auto_parse = false
  | del(.power_user.reasoning.separator)
  | .main_api = "textgenerationwebui"
  | .oai_settings.chat_completion_source = "openrouter"
  | .oai_settings.custom_url = "https://example.invalid/v1"
  | .oai_settings.custom_model = "user-custom-model"
  | .oai_settings.openai_max_context = 131072
  | .oai_settings.temp_openai = 0.7
  | .oai_settings.custom_prompt_post_processing = ""
  | .extension_settings.connectionManager.selectedProfile = "user-uuid-1"
  | .extension_settings.connectionManager.profiles += [
      { id: "nix:yifuwuqi:gemma-4-12b", name: "stale-censored", mode: "cc" },
      { id: "user-uuid-1", name: "User OpenRouter", mode: "cc", api: "openrouter" }
    ]
' "$target" >"${target}.tmp"
mv -f "${target}.tmp" "$target"

"$overlay_bin" "$target" "$default_file" "$overlay_json"

assert_jq '
  ($overlay[0]) as $expected
  | .customUserPref == "keep-me"
  and .power_user.default_persona == "persona.png"
  and .power_user.reasoning.auto_parse == false
  and .power_user.reasoning.separator == $expected.seedPowerUser.reasoning.separator
  and .main_api == "textgenerationwebui"
  and .oai_settings.chat_completion_source == "openrouter"
  and .oai_settings.custom_url == "https://example.invalid/v1"
  and .oai_settings.custom_model == "user-custom-model"
  and .oai_settings.openai_max_context == 131072
  and .oai_settings.temp_openai == 0.7
  and .oai_settings.custom_prompt_post_processing == ""
  and .extension_settings.connectionManager.selectedProfile == "user-uuid-1"
  and ([.extension_settings.connectionManager.profiles[].id]
      == ([$expected.extension_settings.connectionManager.profiles[].id] + ["user-uuid-1"]))
' "$target" "user state preservation or stale nix profile GC failed"
assert_idempotent

# 4a. Every valid nix:* profile stays selected and syncs endpoint, contextLength, and per-model settings.
while IFS= read -r profile_id; do
  jq --arg profile_id "$profile_id" \
    '.extension_settings.connectionManager.selectedProfile = $profile_id' \
    "$target" >"${target}.tmp"
  mv -f "${target}.tmp" "$target"
  "$overlay_bin" "$target" "$default_file" "$overlay_json"
  assert_jq '
    .extension_settings.connectionManager.selectedProfile as $selected
    | ($overlay[0].extension_settings.connectionManager.profiles
        | first(.[] | select(.id == $selected))) as $expected
    | ($expected.oaiSettings + {
        chat_completion_source: $expected.api,
        custom_url: $expected."api-url",
        custom_model: $expected.model,
        openai_max_context: $expected.contextLength
      }) as $expectedOai
    | .main_api == "openai"
    and .extension_settings.connectionManager.selectedProfile == $expected.id
    and (.oai_settings | contains($expectedOai))
    and (.power_user.reasoning | contains($expected.reasoningSettings))
  ' "$target" "valid user-selected nix profile (${profile_id}) did not sync endpoint/context/preset/reasoning settings"
  assert_idempotent
done < <(jq -r '.extension_settings.connectionManager.profiles[].id' "$overlay_json")

# 4b. Selecting a removed nix:* profile falls back to the Nix default and restores its endpoint and contextLength.
jq '.extension_settings.connectionManager.selectedProfile = "nix:yifuwuqi:gemma-4-12b"' \
  "$target" >"${target}.tmp"
mv -f "${target}.tmp" "$target"
"$overlay_bin" "$target" "$default_file" "$overlay_json"
assert_jq '
  ($overlay[0]) as $expected
  | .main_api == "openai"
  and .extension_settings.connectionManager.selectedProfile
      == $expected.extension_settings.connectionManager.selectedProfile
  and (.oai_settings | contains($expected.oai_settings))
' "$target" "removed nix selectedProfile did not fall back to default or restore endpoint"
assert_idempotent

# 5. Corrupted, empty, and non-object JSON fail loudly without modifying target.
for bad in '{broken json' '' '[1, 2, 3]'; do
  printf '%s' "$bad" >"$target"
  if "$overlay_bin" "$target" "$default_file" "$overlay_json" 2>/dev/null; then
    printf 'FAIL: overlay accepted invalid JSON payload (%s)\n' "$bad" >&2
    exit 1
  fi
  actual="$(<"$target")"
  [ "$actual" = "$bad" ]
done
