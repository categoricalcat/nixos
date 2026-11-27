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

alternate_profile_id="$(
  jq -er '
    .oai_settings.custom_url as $default_url
    | .extension_settings.connectionManager.profiles
    | map(select(."api-url" != $default_url))
    | (first // error("no profile uses a different endpoint"))
    | .id
  ' "$overlay_json"
)"

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
  and .oai_settings.chat_completion_source == "custom"
  and .oai_settings.custom_model == $expected.oai_settings.custom_model
  and .oai_settings.custom_url == $expected.oai_settings.custom_url
  and .oai_settings.openai_max_context == $expected.oai_settings.openai_max_context
  and .oai_settings.max_context_unlocked == true
  and .oai_settings.openai_max_tokens == 4096
  and .oai_settings.temp_openai == 1.0
  and .oai_settings.top_p_openai == 0.95
  and .oai_settings.show_thoughts == true
  and .oai_settings.reasoning_effort == "max"
  and .oai_settings.verbosity == "low"
  and .oai_settings.custom_include_body == "reasoning_effort: xhigh"
  and .oai_settings.custom_prompt_post_processing == "semi_tools"
  and .oai_settings.media_inlining == false
  and .oai_settings.stream_openai == true
' "$target" "initial seed missed expected oai_settings or upstream defaults"

assert_jq '
  ($overlay[0]) as $expected
  | .extension_settings.sd.source == "sdcpp"
  and .extension_settings.sd.sdcpp_url == "http://100.69.0.4:11437"
  and .extension_settings.sd.model == $expected.extension_settings.sd.model
  and .extension_settings.sd.width == 1024
  and .extension_settings.sd.height == 1024
  and .extension_settings.sd.steps == 20
  and .extension_settings.sd.scale == 3.5
  and .extension_settings.sd.sampler == "euler"
  and .extension_settings.sd.refine_mode == true
  and (.extension_settings.sd.prompts["0"] | type == "string")
' "$target" "initial seed missed expected sd settings or upstream prompts"

assert_jq '
  ($overlay[0]) as $expected
  | .extension_settings.connectionManager.selectedProfile
      == $expected.extension_settings.connectionManager.selectedProfile
  and ([.extension_settings.connectionManager.profiles[].id]
      == [$expected.extension_settings.connectionManager.profiles[].id])
  and ([.extension_settings.connectionManager.profiles[] | has("contextLength")] | any | not)
' "$target" "initial connectionManager profiles/selectedProfile mismatch"

# 2. Idempotence on default Nix profile: f(f(S)) == f(S).
assert_idempotent

# 3. Preserve user profile, user endpoint, unrelated keys, and GC stale nix:*.
jq '
  .customUserPref = "keep-me"
  | .power_user.default_persona = "persona.png"
  | .main_api = "textgenerationwebui"
  | .oai_settings.chat_completion_source = "openrouter"
  | .oai_settings.custom_url = "https://example.invalid/v1"
  | .oai_settings.custom_model = "user-custom-model"
  | .oai_settings.openai_max_context = 131072
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
  and .main_api == "textgenerationwebui"
  and .oai_settings.chat_completion_source == "openrouter"
  and .oai_settings.custom_url == "https://example.invalid/v1"
  and .oai_settings.custom_model == "user-custom-model"
  and .oai_settings.openai_max_context == 131072
  and .extension_settings.connectionManager.selectedProfile == "user-uuid-1"
  and ([.extension_settings.connectionManager.profiles[].id]
      == ([$expected.extension_settings.connectionManager.profiles[].id] + ["user-uuid-1"]))
' "$target" "user state preservation or stale nix profile GC failed"
assert_idempotent

# 4a. Selecting another valid nix:* profile stays selected and syncs its endpoint and contextLength.
jq --arg profile_id "$alternate_profile_id" \
  '.extension_settings.connectionManager.selectedProfile = $profile_id' \
  "$target" >"${target}.tmp"
mv -f "${target}.tmp" "$target"
"$overlay_bin" "$target" "$default_file" "$overlay_json"
assert_jq '
  .extension_settings.connectionManager.selectedProfile as $selected
  | ($overlay[0].extension_settings.connectionManager.profiles
      | first(.[] | select(.id == $selected))) as $expected
  | .main_api == "openai"
  and .extension_settings.connectionManager.selectedProfile == $expected.id
  and .oai_settings.chat_completion_source == "custom"
  and .oai_settings.custom_url == $expected."api-url"
  and .oai_settings.custom_model == $expected.model
  and .oai_settings.openai_max_context == $expected.contextLength
' "$target" "valid user-selected nix profile was overwritten or endpoint/context did not sync"
assert_idempotent

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
  and .oai_settings.chat_completion_source == "custom"
  and .oai_settings.custom_url == $expected.oai_settings.custom_url
  and .oai_settings.custom_model == $expected.oai_settings.custom_model
  and .oai_settings.openai_max_context == $expected.oai_settings.openai_max_context
' "$target" "removed nix selectedProfile did not fall back to default or restore endpoint"
assert_idempotent

# 5. Corrupted, empty, and non-object JSON fail loudly without modifying target.
for bad in '{broken json' '' '[1, 2, 3]'; do
  printf '%s' "$bad" >"$target"
  if "$overlay_bin" "$target" "$default_file" "$overlay_json" 2>/dev/null; then
    printf 'FAIL: overlay accepted invalid JSON payload (%s)\n' "$bad" >&2
    exit 1
  fi
  actual="$(cat "$target")"
  [ "$actual" = "$bad" ]
done
