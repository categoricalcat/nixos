# SillyTavern Declarative Config & Isolation Plan

## Status: DRAFT — updated 2026-11-22 after `/fp-check` + `/code-quality` review (Option A isolation, exact `settings.json` schema, algebraic profile partition, colocated `models.nix` reads); awaiting exact generation defaults

## Objective

Make SillyTavern's server configuration, API endpoints/model profiles, and inference settings (response size, reasoning effort, context budget, inline-media behavior, image generation backend) declarative in Nix—reading [models.nix](../../../modules/services/ai/models.nix) and [hosts.nix](../../../modules/addresses/hosts.nix) directly from [sillytavern.nix](../../../modules/services/ai/sillytavern.nix)—while keeping characters, personas, worlds, themes, and chat history mutable and out of the repository, and isolating chat storage and logs under `sillytavern`'s dedicated user without LUKS.

## Current state

- **Service module & user boundary** ([sillytavern.nix](../../../modules/services/ai/sillytavern.nix), [users.nix](../../../users/users.nix)):
  - Runs `pkgs.sillytavern` (`1.19.1`) under dedicated system user `sillytavern:sillytavern` with `StateDirectory = "SillyTavern"` (`/var/lib/SillyTavern`) and `systemdHardening` minus `MemoryDenyWriteExecute` and `@chown` ([hardening.nix](../../../modules/hardening.nix)).
  - `StateDirectoryMode` is unset, so systemd defaults `/var/lib/SillyTavern` to `0755` (and default `UMask` leaves newly written files readable by other local accounts).
  - `preStart` removes any `/var/lib/SillyTavern/config.yaml` symlink and, if missing, spawns `sillytavern` for 3 seconds then kills it to bootstrap a default `config.yaml`.
  - `ExecStart` passes `--port=24000 --no-whitelist`. Because `${pkgs.sillytavern}/bin/sillytavern` invokes `src/server-global.js` (`FORCE_GLOBAL_MODE = true`), SillyTavern ignores `--configPath` and `--dataRoot` and resolves `config.yaml` and `data/` via `XDG_DATA_HOME=/var/lib`.
- **Journald / Loki prompt-logging leak**:
  - SillyTavern's shipped `default/config.yaml` sets `logging.minLogLevel: 0` (`DEBUG`).
  - At `DEBUG`, backend endpoints (`src/endpoints/backends/chat-completions.js`, `stable-diffusion.js`, `characters.js`, etc.) log full request bodies and AI responses via `console.debug(...)`, which systemd writes to `journald` (and Vector ships to Loki). Both `yi` and `ai` hold `"systemd-journal"` group membership ([users.nix](../../../users/users.nix)).
  - Setting `logging.minLogLevel >= 1` disables `console.debug` completely (`src/util.js` `setupLogLevel()`).
- **UI/API settings contract** ([ai-rocm.md](../../../docs/src/services/ai-rocm.md), [models.nix](../../../modules/services/ai/models.nix)):
  - LLM endpoints (`http://127.0.0.1:11436/v1` on `yifuwuqi`, `http://100.69.0.4:11436/v1` on `yitaishi`), model selection (`gemma-4-12b`, `gemma-4-12b-uncensored`, `qwen3.8-27b`, `qwen3.8-27b-uncensored`), `stable-diffusion.cpp` config (`http://100.69.0.4:11437`, `euler`, `3.5`, `20`, `1024x1024`, prompt editing), `media_inlining = false`, `openai_max_tokens`, and `reasoning_effort` are configured imperatively in the web UI.
  - On startup (`public/script.js`: `loadOpenAISettings(data, settings.oai_settings ?? settings)`), the frontend reads those fields from `/var/lib/SillyTavern/data/<handle>/settings.json`, **not** from `OpenAI Settings/<preset>.json` (which uses different key names such as `temperature` vs `oai_settings.temp_openai`).
  - The browser continuously persists UI state via `POST /api/settings/save` (`writeFileAtomicSync`), so `settings.json` must stay a regular writable file rather than a `/nix/store` symlink.
- **Privacy invariant**: No AI agent or non-root user (`yi`, `opencode`, `ai-ssh`) may read SillyTavern chat history or `data/` contents at any stage of implementation or verification.

## Decisions

1. **Disjoint ownership partition — Nix-owned overlay vs. mutable user data**:
   - **Nix-owned (`NixOwned`)**:
     - Server config (`config.yaml`, plus optional `SILLYTAVERN_*` secrets via `sops.templates` + `EnvironmentFile` if auth is added).
     - Derived directly inside [sillytavern.nix](../../../modules/services/ai/sillytavern.nix) from [models.nix](../../../modules/services/ai/models.nix) (`modelsForHost`, `imageModelsForHost`) and [hosts.nix](../../../modules/addresses/hosts.nix) (without adding single-consumer SillyTavern helpers to `models.nix`):
       - `extension_settings.connectionManager.profiles`: partitioned by deterministic ID prefix `"nix:"` (`nix:<host>:<modelId>`) for all declared LLMs on `yifuwuqi` and `yitaishi`.
       - `extension_settings.sd`: `source = "sdcpp"`, `sdcpp_url`, `width`, `height`, `steps`, `scale`, `sampler`, `refine_mode = true` from `yitaishi`'s `chroma1-hd`.
     - Exact `settings.json` inference fields under `oai_settings` (never touching `oai_settings.prompts` / `prompt_order`) and `power_user.reasoning` + top-level `main_api = "openai"`:
       - `oai_settings.chat_completion_source = "custom"`, `custom_url`, `custom_model`, `openai_max_tokens`, `openai_max_context`, `max_context_unlocked`, `reasoning_effort`, `media_inlining = false`, `stream_openai = true`, `show_thoughts`, and `temp_openai` / `top_p_openai` / `min_p_openai` / `repetition_penalty_openai`.
       - `power_user.reasoning` (`name`, `auto_parse`, `auto_expand`, `show_hidden`, etc.).
   - **Mutable & out of repo (`MutableUserOwned`, `NixOwned ∩ MutableUserOwned = ∅`)**:
     - `characters/`, `User Avatars/`, `backgrounds/`, `worlds/`, `groups/`, `group chats/`, `chats/`, `backups/`, `themes/`, `extensions/`, `user/`, `vectors/`, `_storage/`, `secrets.json`, `OpenAI Settings/` user presets, user `connectionManager` profiles (`!(id | startswith("nix:"))`), and all remaining `settings.json` keys (personas, active character/chat, tag maps, UI layout).
1. **Generate `config.yaml` by build-time merge onto upstream defaults (zero copy-paste, zero IFD)**:
   - Expose an RFC 42 freeform YAML `config` attrset in [sillytavern.nix](../../../modules/services/ai/sillytavern.nix) (`pkgs.formats.yaml { }`), merged at build time onto `${pkgs.sillytavern}/lib/node_modules/sillytavern/default/config.yaml` (e.g. via a small `pkgs.runCommand` + `jq`/`yq` or `node`, avoiding IFD and avoiding duplicating 396 lines of defaults), and installed `0600` in `preStart`.
   - Eliminates the 3-second spawn-kill race and `config-init.js` write warnings.
   - Pin `logging.minLogLevel = 2` (`WARN`, or `1` `INFO`) so chat prompts and responses are never logged to `journald` / Loki.
1. **Algebraically idempotent `jq` overlay for `settings.json`**:
   - Precondition: if `/var/lib/SillyTavern/data/<handle>/settings.json` is absent, seed it from `${pkgs.sillytavern}/lib/node_modules/sillytavern/default/content/settings.json`; if present and invalid JSON, fail `preStart` without modifying the file.
   - Profile partition update: replace `{ p | p.id startsWith "nix:" }` with `$nixProfiles` while preserving all user profiles (`!(id | startswith("nix:"))`) in order, setting `selectedProfile` only when `null` or pointing to a removed `nix:*` profile.
   - Scalar/object overlay: apply recursive object merge (`*`) on the disjoint `NixOwned` keys only, writing atomically via `mktemp` + `mv` (`0600`).
   - Laws: **idempotent** (`overlay(overlay(S)) == overlay(S)`), **garbage-collects** removed `models.nix` entries cleanly, and leaves `MutableUserOwned` untouched.
   - Operational caveat: open browser tabs across a `sillytavern.service` restart hold stale in-memory state and must be refreshed before saving settings.
1. **Isolation via per-service user boundary (Option A — no LUKS, zero boot friction)**:
   - Keep `sillytavern.service` under its dedicated `sillytavern:sillytavern` system user (matching `yifuwuqi`'s per-service user separation; `opencode` and `filebrowser` run as `yi`, and `ai-ssh` denies `/var/lib`).
   - Tighten `StateDirectoryMode = "0700"` and `UMask = "0077"` on `sillytavern.service`, plus `chmod 700 /var/lib/SillyTavern /var/lib/SillyTavern/data` in `preStart`, so neither `yi`, `opencode`, `ai-ssh`, nor sibling daemons can read `/var/lib/SillyTavern`.
   - **Documented trade-off**: Without disk encryption, `root` and offline physical disk reads can still read `/var/lib/SillyTavern/data` on disk; directory-level `fscrypt`/`gocryptfs` on `chats/` or encrypted backups can be layered independently later without altering config management.
   - **Agent blindfold**: `preStart` runs locally inside `sillytavern.service`; no AI agent ever inspects `/var/lib/SillyTavern/data` or chat files.

## Phases

### Phase 1 — Permission lockdown, log redaction, & declarative `config.yaml`

- Set `StateDirectoryMode = "0700"` and `UMask = "0077"` in [sillytavern.nix](../../../modules/services/ai/sillytavern.nix), and ensure `0700` on `/var/lib/SillyTavern` and `/var/lib/SillyTavern/data` in `preStart`.
- Replace the `preStart` 3-second background-kill hack with a build-time merge of Nix overrides onto `${pkgs.sillytavern}/.../default/config.yaml`, installed `0600` in `preStart`, encoding port, proxy settings (`whitelistMode = false`, `forwardedHeaders`, `hostWhitelist`, `backups.chat`, `extensions.autoUpdate`), and **`logging.minLogLevel = 2`**.
- Keep `EnvironmentFile` hook ready via `sops.templates` if authentication (`basicAuthMode` or `enableUserAccounts`) is enabled later.

### Phase 2 — Declarative API profiles & inference settings overlay

- Read `ai.modelsForHost` and `ai.imageModelsForHost` directly inside [sillytavern.nix](../../../modules/services/ai/sillytavern.nix) using `allAddresses` to generate:
  - `nix:*` `connectionManager` profiles for `yifuwuqi` (`http://127.0.0.1:${llamaPort}/v1`) and `yitaishi` (`http://${yitaishiTailnetIp}:${llamaPort}/v1`)
  - `extension_settings.sd` (`source = "sdcpp"`, `sdcpp_url`, `width`, `height`, `steps`, `scale`, `sampler`, `refine_mode = true`).
- Expose concise RFC 42 freeform `settings` / `config` options (avoiding redundant single-caller scalar option boilerplate) and encode the chosen `oai_settings` + `power_user.reasoning` defaults in `hosts/yifuwuqi/services.nix` (or `sillytavern.nix`).
- Implement the `jq` overlay script via `pkgs.writeShellApplication` (checked by `shellcheck` at build time) and add a pure `pkgs.runCommand` check in `nix/checks.nix` (or `sillytavern` checks) testing:
  - Empty/missing seed -> valid JSON containing Nix overlay
  - Idempotence (`overlay(overlay(S)) == overlay(S)`)
  - Preservation of user profiles (`!startswith("nix:")`) and unrelated keys (`characters`/UI state) + removal of stale `nix:*` profiles
  - Non-destructive failure on corrupted input JSON.

### Phase 3 — Verification, docs, and plan retirement

- Run `nix fmt -- --fail-on-change` (`treefmt` + `deadnix` + `statix` + `nixf-diagnose` + `nixfmt`), `nix flake check --no-build`, and build the `yifuwuqi` `sillytavern` closure + `jq` overlay test derivation.
- User deploys to `yifuwuqi`, refreshes the browser UI, and verifies APIs, models, SD settings, `0700` permissions, clean `journalctl -u sillytavern` logs (zero prompt/reply dumps), and intact characters/chats.
- Update [ai-rocm.md](../../../docs/src/services/ai-rocm.md), [hosted-services.md](../../../docs/src/services/hosted-services.md), and [yifuwuqi.md](../../../docs/src/hosts/yifuwuqi.md), then delete `docs/src/plans/sillytavern-declarative-and-encrypted-plan.md` in the completing change set.

## Rollout order

- [ ] **0.1** Answer the open questions below (exact inference defaults and single-user vs auth) (User).
- [ ] **1.1** Update [sillytavern.nix](../../../modules/services/ai/sillytavern.nix) with `StateDirectoryMode = "0700"`, `UMask = "0077"`, declarative `config.yaml` merge, and `logging.minLogLevel = 2` (AI).
- [ ] **2.1** Add `models.nix` + `allAddresses` profile/SD projections and RFC 42 `jq` overlay in [sillytavern.nix](../../../modules/services/ai/sillytavern.nix), plus the `jq` overlay property/example check (AI).
- [ ] **2.2** Run formatting (`nix fmt -- --fail-on-change`), `nix flake check --no-build`, and build the `yifuwuqi` `sillytavern` + test derivations (AI).
- [ ] **3.1** Deploy to `yifuwuqi` and verify in SillyTavern UI that APIs, models, SD settings, `0700` permissions, quiet journald logs, and existing characters/chats are intact (User).
- [ ] **3.2** Update documentation ([ai-rocm.md](../../../docs/src/services/ai-rocm.md), [hosted-services.md](../../../docs/src/services/hosted-services.md), [yifuwuqi.md](../../../docs/src/hosts/yifuwuqi.md)), re-run `nix flake check --no-build`, and delete this plan file upon completion (AI).

## Open questions

1. **Exact declarative inference defaults**: Which values do you want pinned in Nix?
   - Default active model/profile (`gemma-4-12b-uncensored` on `yifuwuqi` vs `qwen3.8-27b-uncensored` on `yitaishi`),
   - `oai_settings.openai_max_tokens` (e.g. `2048`, matching the budget comment in [models.nix](../../../modules/services/ai/models.nix#L37)), `openai_max_context` / `max_context_unlocked`,
   - `oai_settings.reasoning_effort` (`"auto"`, `"low"`, `"medium"`, `"high"`, `"min"`, `"max"`), `show_thoughts`, and sampler defaults (`temp_openai`, `top_p_openai`, `min_p_openai`, `repetition_penalty_openai`)?
1. **SillyTavern user handle / auth**: Confirm whether SillyTavern stays single-user (`default-user`, `enableUserAccounts = false`, protected by the `yirukou` LAN allowlist + ingress) or whether you also want declarative `basicAuthMode` / user accounts enabled (credentials in `secrets/secrets.yaml` via `nix run .#secrets`).
1. **Log level (`1` INFO vs `2` WARN)**: Confirm whether `logging.minLogLevel = 2` (`WARN`, suppressing startup/access chatter too) or `1` (`INFO`, keeping startup/connection status without `console.debug` prompt/response dumps) is preferred.
