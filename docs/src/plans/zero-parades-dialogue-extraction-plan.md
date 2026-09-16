# Zero Parades Dialogue & Voiceover Extraction Package Plan

## Objective

Create a pure declarative Nix package `packages/zero-parades` in the NixOS repository that extracts all dialogue lines, speaker tags, skill checks, and flow metadata from ***Zero Parades: For Dead Spies*** (Steam on `yitaishi`), matches every line to its recorded voice acting in FMOD SoundBanks, and outputs system binaries for dialogue extraction and an interactive minimal web player ("pick line > press play").

## Current State

- **Game Installation:** Local Steam install on `yitaishi` at `/home/yi/.local/share/Steam/steamapps/common/Zero Parades/`.
- **Dialogue Data Extracted:**
  - 63,217 dialogue lines extracted across 301 FELDRuntime chunk assets into CSV and JSON.
  - 100 distinct speakers indexed (protagonist `herschel`, `narrator`, faculties/skills like `presence`, `wits`, `focus`, `senses`, `nerve`, `muscle`, and NPCs like `duchess`, `yana`, `holocene`, `drgonza`, etc.).
- **Voiceover Audio Architecture Discovered:**
  - Middleware: FMOD Studio sound banks in `ZeroParades_Data/StreamingAssets/SoundBanks/` (332 voiceover banks, ~3.1 GB).
  - Deterministic 1-to-1 matching key:
    - SoundBank file: `BNK_VO_{flow_id}.bank`
    - Audio sample name inside bank: `{card_id}-dialog_lines` (or `{card_id}-alternativeN` for variants)
    - Audio encoding: FSB5 Vorbis (48kHz mono broadcast quality).
  - Verified test extraction: successfully decoded sample `0tuepkdj_92o9e7z-dialog_lines` from `BNK_VO_xuew7v32xqk0h1du.bank` into a standard, valid Ogg Vorbis stream.
- **Repository Package Architecture:**
  - `packages/zero-parades/default.nix` is a 100% pure declarative Nix derivation:
    - Pure Nix-packaged dependencies: `fsb5`, `tpk_ar`, and `unitypy` built via `buildPythonPackage`.
    - Bundles `libvorbis` and `libogg` via `makeWrapper` in `LD_LIBRARY_PATH`.
    - Zero imperative runtime commands (no pip, no virtualenv, no user-cache hacks).
  - Wired via `perSystem.packages.zero-parades` in `flake.nix`.

## Decisions

- **Package Location & Structure:**
  - `packages/zero-parades/` contains:
    - `default.nix`: Pure Nix derivation packaging all python modules, wrapping dependencies, and generating binaries in `$out/bin`.
    - `src/extract_dialogue.py`: Core extraction engine.
    - `src/player_server.py`: On-demand FSB5 audio streamer and API server.
    - `src/web/`: Minimal, clean single-page web player (HTML/CSS/JS).
- **Output Binaries in `$out/bin/`:**
  1. `zero-parades-extract`: CLI command to extract dialogue from the game into CSV / JSON.
  1. `zero-parades-play`: CLI command to launch the voiceover player server and open the browser.
  1. `zero-parades`: Unified dispatcher binary (`zero-parades extract ...`, `zero-parades play ...`).
- **Audio Delivery Architecture:**
  - **On-Demand Streaming:** Rather than decompressing 3.1 GB of audio into loose files, the backend decodes the requested Vorbis sample from `BNK_VO_{flow_id}.bank` in \<5ms, streaming native `audio/ogg` to the browser with LRU caching.
- **Minimal UI Design ("pick line > press play"):**
  - Instant live search & filter by speaker or text query.
  - Clean table displaying Speaker, Text, Skill DC Threshold, and Play status.
  - Clicking any row plays the matching voiceover track immediately via HTML5 `<audio>`.

## Phases

### Phase 1: Research & Object Model Discovery (Completed)

- Verified Steam install path on `yitaishi`.
- Verified asset bundle checksum and catalog mappings in `catalog.json`.
- Reverse-engineered TypeTree deserialization structure for FELDRuntime chunk assets.

### Phase 2: Dialogue Extraction Implementation (Completed)

- Implemented and verified extraction logic across all 301 chunk assets.
- Generated complete CSV and JSON datasets (63,217 lines, 100 speakers).

### Phase 3: Audio Reverse-Engineering & Matching (Completed)

- Mapped conversation `flow_id` directly to `BNK_VO_{flow_id}.bank`.
- Mapped dialogue `card_id` directly to `{card_id}-dialog_lines` within FSB5 banks.
- Verified Vorbis decoding using `fsb5`, `libvorbis`, and `libogg` to output standard `audio/ogg`.

### Phase 4: Pure Declarative Nix Package & Binaries (Completed)

- Packaged `fsb5`, `tpk_ar`, and `unitypy` declaratively inside `packages/zero-parades/default.nix`.
- Wrapped `zero-parades-extract` and `zero-parades-play` with `libvorbis` and `libogg`.
- Wired into `flake.nix` `perSystem.packages.zero-parades`.
- Verified `nix build .#zero-parades` and runtime execution without any imperative commands or caches.
- Added intelligent handling for unvoiced lines:
  - 61,785 lines (97.7%) have recorded voiceover in `BNK_VO_{flow_id}.bank`.
  - 1,432 lines (2.3%) are unvoiced ambient floating text (`bark`) or thought orbs.
  - Player sorts voiced dialogue flows first, defaults to "Voiced only" mode with a UI toggle, shows `VO` / `TEXT ONLY` badges, and supports HTTP Range (206) & HEAD requests.

## Rollout Order

1. Built and verified `nix build .#zero-parades --no-link`.
1. Verified `nix run .#zero-parades -- play` and `nix run .#zero-parades -- extract`.
1. Deleted all temporary / ad-hoc virtualenvs.

## Open Questions

- None. Both dialogue extraction and audio player run purely declaratively from the Nix store.
