# SillyTavern Local Uncensored Audio & TTS Plan

## Status: DEFERRED — architecture and engine options researched 2026-11-23; implementation deferred pending engine selection

## Objective

Add local, uncensored Text-to-Speech (TTS) character voice synthesis to SillyTavern (`https://sillytavern.aset.love`) with declarative NixOS configuration in `modules/services/ai/sillytavern.nix` (and `modules/services/ai/models.nix` / `modules/addresses/hosts.nix` if backed by a host daemon), zero cloud telemetry or content filtering, and preservation of user-assigned character `voiceMap` mappings across restarts.

## Current state

- **LLM & image topology** (`modules/services/ai/models.nix`, `modules/services/ai/llama-cpp.nix`, `modules/services/ai/sd-cpp.nix`):
  - `yifuwuqi` (Radeon 680M APU, 4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM) serves `deepseek-v4-pro-qwen3.5-9b-uncensored` (`i1-Q6_K`, STEM/OpenCode `research` default) and `gemma-4-12b-uncensored` (`Q4_K_M`, 24/7 roleplay default) via `llama-server` router (`--models-max 1`, `--no-mmproj`).
  - `yitaishi` (Radeon RX 7900 XTX, 24 GiB VRAM) serves `qwen3.8-27b-uncensored` (`UD-Q4_K_XL`, STEM/reasoning) and `gemma-4-26b-a4b-uncensored` (`Q4_K_M`, roleplay MoE) via `llama-server` router (`--models-max 1`), plus `chroma1-hd` (`Q8_0`) via `sd-server` (`--offload-to-cpu`).
- **SillyTavern TTS extension** (`pkgs.sillytavern` `1.19.1`, `public/scripts/extensions/tts/`):
  - Upstream `defaultSettings` (`public/scripts/extensions/tts/index.js`) defaults `currentProvider` to `"ElevenLabs"` (cloud) with `ttsEnabled = false`.
  - SillyTavern `1.19.1` ships native client providers for:
    - **`Kokoro`** (`public/scripts/extensions/tts/kokoro.js` + `kokoro-worker.js`): runs `onnx-community/Kokoro-82M-v1.0-ONNX` (`q8`/`fp16`/`fp32`) directly inside the browser via WebGPU or WebAssembly (`28` built-in US/UK voices such as `af_heart`, `af_bella`, `am_fenrir`, `bf_emma`) with zero server RAM/VRAM footprint.
    - **`OpenAI Compatible`** (`public/scripts/extensions/tts/openai-compatible.js`): posts `{ model, input, voice, response_format: "mp3", speed }` through SillyTavern's backend `/api/openai/custom/generate-voice` route to any self-hosted `/v1/audio/speech` daemon.
    - **`Chatterbox`** (`public/scripts/extensions/tts/chatterbox.js`): connects to a self-hosted Chatterbox TTS server (`GET /get_predefined_voices`, `GET /get_reference_files`, `POST /tts`) supporting zero-shot `.wav` character voice cloning (`voice_mode: "clone"`), `exaggeration` (`0..2`), and `cfg_weight` (`0..1`).
  - **Voice-map persistence hazard**: Each provider stores user-assigned `{ "<characterName>": "<voiceId>" }` mappings inside `extension_settings.tts.<Provider>.voiceMap` in `settings.json`. Because `jq`'s recursive object merge (`*`) merges nested objects, overlaying `extension_settings.tts.<Provider>` in `sillytavern-settings-overlay.sh` must never overwrite existing user `voiceMap` keys.
- **Locked `nixpkgs` packages** (`/etc/nix/inputs/nixpkgs`):
  - `pkgs.pocket-tts` (`kyutai-labs/pocket-tts` `v4.0.1`, MIT license): 100M-parameter CPU-efficient TTS + zero-shot voice cloning with built-in FastAPI/Uvicorn server.
  - `pkgs.tts` (`idiap/coqui-ai-TTS` `0.26.2`, MPL-2.0) and `nixos/modules/services/audio/tts.nix` (`services.tts.servers`).
  - `pkgs.wyoming-piper` / `pkgs.piper-tts`.
  - `pkgs.llama-cpp` includes `llama-tts` (OuteTTS / speech-LLM GGUF CLI, not an HTTP server).

## Decisions

1. **Candidate local uncensored TTS tiers (to be chosen before Phase 1)**:
   - **Tier 1 — Zero-daemon in-browser `Kokoro-82M` (`Kokoro` provider)**:
     - Preconfigure `extension_settings.tts` in `modules/services/ai/sillytavern.nix` (`currentProvider = "Kokoro"`, `device = "webgpu"`, `dtype = "q8"`, `defaultVoice = "af_heart"`, `narrate_quoted_only = true`, `pass_asterisks = false`, `skip_codeblocks = true`, `skip_tags = true`).
     - *Pros*: `0 MiB` RAM/VRAM on `yifuwuqi` and `yitaishi`; instant setup.
     - *Cons*: Runs in client browser (heavy on mobile/tablet clients; no custom `.wav` voice cloning).
   - **Tier 2 — Always-on 24/7 lightweight server daemon on `yifuwuqi` (`Kokoro-FastAPI` or `pkgs.pocket-tts`) via `OpenAI Compatible` provider**:
     - Run a hardened `DynamicUser` systemd service on loopback (`yifuwuqi`) exposing `/v1/audio/speech`, wired into SillyTavern's `OpenAI Compatible` provider (`/api/openai/custom/generate-voice` proxies server-side, so no new public ingress vhost is required).
     - *Pros*: Works identically across desktop and mobile browsers; \<500 MiB RAM on CPU (`Kokoro-82M` ONNX or `pocket-tts` 100M).
   - **Tier 3 — Expressive zero-shot voice cloning on `yitaishi` (`Chatterbox` or `Orpheus-3B`)**:
     - Run Chatterbox TTS (`Chatterbox` provider) or Orpheus-3B (`OpenAI Compatible` provider with `<laugh>`, `<sigh>`, `<gasp>` emotion tags) on `yitaishi` (`100.69.0.4`, RX 7900 XTX), demand-loaded or CPU/GPU-shared alongside `llama-cpp` and `sd-cpp`.
     - *Pros*: Highest acting quality, emotional prosody, and zero-shot character voice cloning from short reference audio files.
     - *Cons*: Requires `yitaishi` to be powered on (and note that SillyTavern's `ChatterboxTtsProvider` calls `fetch("${provider_endpoint}/...")` directly from the browser rather than through the SillyTavern Node backend, whereas `OpenAI Compatible` proxies through `/api/openai/custom/generate-voice` on `yifuwuqi`).
1. **Narrate dialogue, not markup or thoughts**:
   - Regardless of engine tier, declarative TTS defaults in `sillytavern.nix` will set `skip_codeblocks = true`, `skip_tags = true`, `pass_asterisks = false`, and `narrate_dialogues_only = true` (or `narrate_quoted_only = true`) so `*action narration*`, code blocks, and HTML/thought tags are never read aloud.
1. **Preserve user `voiceMap` assignments in `sillytavern-settings-overlay.sh`**:
   - Do not include `voiceMap` in Nix's `$scalarOverlay` under `extension_settings.tts.<Provider>`, and verify in `modules/services/ai/sillytavern-settings-overlay-test.sh` that existing `extension_settings.tts.<Provider>.voiceMap` entries survive service restarts unchanged.

## Phases

### Phase 1 — Declarative SillyTavern TTS Overlay & VoiceMap Invariant

- Add `extension_settings.tts` defaults to `modules/services/ai/sillytavern.nix` for the selected provider (`enabled = false` by default or `true` if requested, dialogue-only filtering, and provider endpoint/model defaults).
- Extend `modules/services/ai/sillytavern-settings-overlay-test.sh` to assert that user-configured `extension_settings.tts.<Provider>.voiceMap` character-to-voice mappings are preserved idempotently ($f(f(S)) = f(S)$).

### Phase 2 — Self-Hosted TTS Daemon Module (if Tier 2 or Tier 3 is selected)

- Register the TTS service port in `modules/addresses.nix` / `modules/addresses/hosts.nix` and declare the model artifact in `modules/services/ai/models.nix` (with pinned SHA256 verification).
- Create the hardened systemd service module under `modules/services/ai/` adopting `systemdHardening` (and register any required exceptions in `modules/hardening.nix` for the `hardening-baseline` contract in `nix/checks.nix`).
- Route requests through SillyTavern's backend proxy (`/api/openai/custom/generate-voice`) or local ingress so browser clients on LAN (`https://sillytavern.aset.love`) do not hit cross-origin / mixed-content blocks.

### Phase 3 — Verification, Documentation, & Plan Retirement

- Run `nix fmt -- --fail-on-change`, `nix flake check --no-build`, and build `.#checks.x86_64-linux.{sillytavern-settings-overlay,contracts,docs,docs-registry-sync}` plus the target host systemd units.
- Update `docs/src/services/ai-rocm.md`, `docs/src/services/hosted-services.md`, and host profile docs (`docs/src/hosts/yifuwuqi.md` / `docs/src/hosts/yitaishi.md`).
- Delete `docs/src/plans/sillytavern-audio-tts-plan.md` in the completing change set.

## Rollout order

- [ ] **0.1** Resolve the open questions below (TTS engine tier, target host, and whether TTS should auto-enable on startup) (User).
- [ ] **1.1** Implement declarative `extension_settings.tts` defaults in `modules/services/ai/sillytavern.nix` and `voiceMap` preservation assertions in `modules/services/ai/sillytavern-settings-overlay-test.sh` (AI).
- [ ] **2.1** If Tier 2 or Tier 3 is chosen, implement the TTS daemon module, `models.nix` entry, `addresses.nix` port, and `modules/hardening.nix` inventory entry (AI).
- [ ] **2.2** Run `nix fmt -- --fail-on-change`, `nix flake check --no-build`, and build all affected checks and systemd units (AI).
- [ ] **3.1** Switch target host(s) and verify character voice preview and message narration in `https://sillytavern.aset.love` (User).
- [ ] **3.2** Update documentation and retire `docs/src/plans/sillytavern-audio-tts-plan.md` in the completing change set (AI).

## Open questions

1. **Engine tier & host placement**: Do you want:
   - **Tier 1**: In-browser `Kokoro-82M` (`WebGPU`/`WASM`, zero server load, 28 built-in voices, no voice cloning),
   - **Tier 2**: 24/7 CPU server daemon on `yifuwuqi` (`Kokoro-FastAPI` or `pkgs.pocket-tts` via `OpenAI Compatible`, working on mobile browsers too), or
   - **Tier 3**: Expressive GPU voice cloning on `yitaishi` (`Chatterbox` or `Orpheus-3B` with inline emotion tags)?
1. **Narration scope**: Should TTS narrate **only quoted dialogue** (`"..."`, `narrate_quoted_only = true`), or **all non-asterisk text** (`narrate_dialogues_only = true`, `pass_asterisks = false`)?
1. **Default toggle**: Should `extension_settings.tts.enabled` remain `false` on startup (toggled on per session in the UI) or default to `true` with `auto_generation = true`?
