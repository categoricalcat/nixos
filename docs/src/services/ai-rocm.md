# AI & Local Inference Infrastructure

This document details the self-hosted LLM inference stack, Vulkan acceleration, declarative model registry, router-mode serving, agent tooling, and companion web interfaces.

______________________________________________________________________

## 1. Inference Topology

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                     yifuwuqi (24/7 Core Server)                         │
│  AMD Ryzen 9 6900HX · Radeon 680M APU (4 GiB VRAM + 9.65 GiB GTT)       │
│  llama-cpp.service (Vulkan RADV · 127.0.0.1:11436 · --models-max 1)     │
│   ├─ deepseek-v4-pro-qwen3.5-9b-uncensored  (i1-Q6_K · 64k · think on)  │
│   └─ gemma-4-12b-uncensored                 (Q4_K_M  · 64k · think on)  │
└───────────────────┬───────────────────────────────┬─────────────────────┘
                    │ loopback                      │ loopback
                    ▼                               ▼
         ┌────────────────────┐          ┌────────────────────┐
         │ SillyTavern UI     │          │ Opencode Agent     │
         │ (:24000 Web UI)    │          │ (:24010 / CLI)     │
         └─────────┬──────────┘          └──────────┬─────────┘
                   │ Tailscale (:11436 / :11437)    │ Tailscale (100.69.0.4:11436)
                   ▼                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     yitaishi (24 GiB Workstation)                       │
│  AMD Ryzen 7 7700X · Radeon RX 7900 XTX (24 GiB GDDR6 · gfx1100)        │
│  llama-cpp.service (Vulkan RADV · 127.0.0.1,100.69.0.4:11436 · max 1)   │
│   ├─ gemma-4-26b-a4b-uncensored  (Q4_K_M    · 96k ctx · thinking on)    │
│   └─ qwen3.8-27b-uncensored      (UD-Q4_K_XL · 96k ctx · thinking on)   │
│  sd-cpp.service (Vulkan RADV · 0.0.0.0:11437 · tailscale0 + localhost)  │
│   └─ chroma1-hd                  (Q8_0 · 1024x1024 · --offload-to-cpu)  │
└─────────────────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Router-Mode Model Serving (`modules/services/ai/llama-cpp.nix`)

- **Vulkan Backend**: Configured via `services.llama-cpp-node.backend = "vulkan"` (`rocmSupport = false` explicitly so hosts with global `nixpkgs.config.rocmSupport = true` reuse the cached Vulkan-only `llama-cpp` build). Uses Vulkan compute rather than ROCm on the Ryzen 680M APU because ROCm (`gfx1030` binaries forced onto `gfx1035`) corrupts memory beyond ~4–5k tokens.
- **Native Router Mode (`--models-preset` + `--models-max 1`)**: Each host runs a single `llama-cpp.service` router on port `11436` (`modules/addresses.nix`). The router starts in `<0.1s` with `0 MiB` GPU memory allocated, loads models on demand when requested by model ID, and LRU-evicts any loaded model before spawning the alternate preset so two models can never simultaneously OOM VRAM/GTT.
- **Preset Optimizations**: Child instances inherit `--device Vulkan0` and `--split-mode none` (pinning execution to `Vulkan0` and preventing context creation or tensor splits on `yitaishi`'s `512 MiB` `gfx1036` iGPU), `-ngl 99`, `-fa on` (FlashAttention), `--cache-type-k q8_0 --cache-type-v q8_0`, `--parallel 1`, `--jinja`, `--no-mmproj`, `dedup-cache-models = true` (hiding raw `[cache]` duplicates in `/models`), and `--sleep-idle-seconds 300`.
- **Idle unload**: After 300s with no requests the child sleeps. `llama-cpp-idle-unload.service` streams `/models/sse` and immediately `POST`s `/models/unload` when a model enters `sleeping`, which exits the child and releases its RAM and swap. The next request loads the model again.
- **Network Binding**: Loopback-only (`127.0.0.1:11436`) on `yifuwuqi`; loopback plus Tailscale (`127.0.0.1,100.69.0.4:11436`, firewall-scoped to `tailscale0`) on `yitaishi`.

______________________________________________________________________

## 3. Central Model Registry (`modules/services/ai/models.nix`)

`models.nix` declares two hardware-sized uncensored LLM models per host (all Heretic-abliterated) plus the uncensored `chroma1-hd` diffusion model on `yitaishi`:

| Model ID                                | Target Host | Port    | Context / Resolution | Quantization | Source Repository                                                    | Notes                      |
| --------------------------------------- | ----------- | ------- | -------------------- | ------------ | -------------------------------------------------------------------- | -------------------------- |
| `deepseek-v4-pro-qwen3.5-9b-uncensored` | `yifuwuqi`  | `11436` | `65536`              | `i1-Q6_K`    | `mradermacher/DeepSeek-V4-Pro-Qwen3.5-9B-UNCENSORED-heretic-i1-GGUF` | Tools: Yes, Reasoning: Yes |
| `gemma-4-12b-uncensored`                | `yifuwuqi`  | `11436` | `65536`              | `Q4_K_M`     | `zaakirio/gemma-4-12b-it-uncensored-GGUF`                            | Tools: Yes, Reasoning: Yes |
| `gemma-4-26b-a4b-uncensored`            | `yitaishi`  | `11436` | `98304`              | `Q4_K_M`     | `llmfan46/gemma-4-26B-A4B-it-ultra-uncensored-heretic-GGUF`          | Tools: Yes, Reasoning: Yes |
| `qwen3.8-27b-uncensored`                | `yitaishi`  | `11436` | `98304`              | `UD-Q4_K_XL` | `ajgazin/Qwen3.8-27B-Heretic-Dynamic-GGUF`                           | Tools: Yes, Reasoning: Yes |
| `chroma1-hd`                            | `yitaishi`  | `11437` | `1024x1024`          | `Q8_0`       | `silveroxides/Chroma1-HD-GGUF`                                       | Uncensored 8.9B Flux DiT   |

______________________________________________________________________

## 4. Uncensored Image Generation (`modules/services/ai/sd-cpp.nix`)

- **Engine (`pkgs.stable-diffusion-cpp`)**: Runs `sd-server` built with `vulkanSupport = true` and `rocmSupport = false`, pinned to `--backend vulkan0` on `yitaishi`'s RX 7900 XTX (`24 GiB` VRAM).
- **Native Web UI**: Builds the frontend pinned inside the same stable-diffusion.cpp source and serves it at `https://sd-cpp.aset.love` through yirukou (`http://100.69.0.4:11437/` over Tailscale). It exposes exact prompts, seeds, dimensions, guidance, init/reference/mask/control images, high-resolution passes, previews, and cancellation without loading another model server.
- **VRAM Coexistence (`--offload-to-cpu`)**: Keeps source parameters in host RAM, prefetches and caches GPU replicas while sampling, then reclaims them after the request so `qwen3.8-27b-uncensored` can load later. A 1024x1024 probe held the RX 7900 XTX at 100% utilization and 350–392 W with about 12 GiB total VRAM in use; idle usage returned to about 2 GiB.
- **Verified Cache (`sd-cpp-fetch`)**: A background service verifies every artifact against its pinned SHA256 digest, downloading missing or mismatched weights into `/var/cache/sd-cpp` before starting `sd-server` without delaying activation.
- **Network Scope**: Listens on port `11437`, restricted by systemd `IPAddressAllow = [ "localhost" "100.64.0.0/10" ]` and `yitaishi`'s `tailscale0` firewall rule.

______________________________________________________________________

## 5. AI Client Ecosystem & Web Interfaces

### 5.1 SillyTavern Companion (`modules/services/ai/sillytavern.nix`)

- **Domain**: `https://sillytavern.aset.love` (proxied to loopback port `24000` via local ingress).
- **Security & Isolation**: Dedicated non-root user `sillytavern` under strict systemd hardening, `StateDirectoryMode = "0700"`, `UMask = "0077"`, `0700` data directory permissions, `0600` config/settings, loopback-only (`listen = false`), single passwordless `default-user` (`enableUserAccounts = false`), and `minLogLevel = 1` (`INFO`) so prompt/reply debug payloads never reach journald or Loki.
- **Declarative Config & Profiles**: Ordered after `llama-cpp.service`. `config.yaml` is generated via `pkgs.formats.yaml` (with `hostWhitelist.hosts = [ "sillytavern.aset.love" ]`, `hostWhitelist.scan = false`, `extensions.autoUpdate = false`; SillyTavern populates omitted upstream defaults from `default/config.yaml` on startup), and `settings.json` receives an idempotent startup overlay derived directly from `models.nix` and `hosts.nix`:
  - **Default Active Chat Profile**: `yifuwuqi / gemma-4-12b-uncensored` (`http://127.0.0.1:11436/v1`, `chat_completion_source = "custom"`, `openai_max_context = 65536`, `openai_max_tokens = 4096`, `stream_openai = true`, `temp_openai = 1.0`, `top_p_openai = 0.95`, `show_thoughts = true`, `reasoning_effort = "max"`, `verbosity = "low"`, `custom_include_body = "reasoning_effort: xhigh"`, `custom_prompt_post_processing = "semi_tools"`, `media_inlining = false` since local LLMs have `--no-mmproj`).
  - **Connection Manager (`nix:*`)**: Exposes all four uncensored LLM profiles (`nix:yifuwuqi:deepseek-v4-pro-qwen3.5-9b-uncensored`, `nix:yifuwuqi:gemma-4-12b-uncensored`, `nix:yitaishi:gemma-4-26b-a4b-uncensored`, and `nix:yitaishi:qwen3.8-27b-uncensored`), while preserving user-created profiles and unrelated UI state.
  - **Image Generation (`sdcpp`)**: Preconfigured for `chroma1-hd` on `http://100.69.0.4:11437` (`sampler = "euler"`, `scale = 3.5`, `steps = 20`, `1024x1024`, `refine_mode = true` prompt editing).

### 5.2 Opencode Agent (`modules/services/opencode.nix`, `users/programs/opencode.nix`)

- **Domain**: `https://opencode.aset.love` (proxied to port `24010`).
- **Providers**: Exposes `deepseek` and `yitaishi` (`127.0.0.1:11436` on `yitaishi`, `100.69.0.4:11436` over Tailscale elsewhere) everywhere, plus `local` (`127.0.0.1:11436`) only on `yifuwuqi`, whose router is loopback-only. The Firecrawl MCP is registered only on `yifuwuqi`, where the Firecrawl API listens on `localhost:24002`; its tools are wired into the `research` (web-only lockdown), `build`, and `plan` agents there. Other hosts use the built-in default agent (remote Firecrawl use goes via `ssh`).

### 5.3 Firecrawl MCP Server (`packages/firecrawl-mcp`)

- **Strictly-Type-Checked Stdio Bridge**: Custom MCP server — strictest-`tsc` type-checked at build, example- and seeded-property-tested at check (`node --test` against mocked HTTP; not formal verification), zero runtime dependencies (Node native type stripping), registered only on `yifuwuqi`. One module per tool (`search.ts`, `scrape.ts`, `map.ts`) behind a JSON-RPC entry (`firecrawl-mcp.ts`) that dispatches on own keys only and rejects any argument the tool's schema does not list. `scrape` and `map` target the self-hosted Firecrawl API with only the options this deployment serves, bounded to upstream v2.11.0's zod (scrape: `waitFor` ≤ 60000 ms and at most half of `timeout`, `timeout` ≥ 1000 ms, formats `markdown`/`html`/`rawHtml`/`links`/`images`, where any format beyond markdown returns the whole document as JSON; map: `limit` 1–100000); `search` targets the local SearXNG JSON API (`localhost:24888`).
- **1:1 Lossless Search**: Every `firecrawl_search` parameter maps to exactly one SearXNG Search API parameter and keeps SearXNG's own meaning — `categories` and `engines` are both forwarded and unioned, explicit `time_range` is never dropped (news queries included), `language`/`pageno` are validated against what the instance accepts (`pt_BR` canonicalizes to `pt-BR`), and `timeout_limit` is bounded to the instance's `outgoing.max_request_timeout` window `(0, 15]`; `safesearch` is not a parameter at all — every request pins `safesearch=0` so filtering is always off regardless of instance defaults. Category and engine names come from the instance's own `GET /config` listing, which also fills the `categories` enum in `tools/list`. The response is SearXNG's whole JSON answer verbatim (`results` plus `answers`, `infoboxes`, `suggestions`, `corrections`, `unresponsive_engines`), with a single retry only when the first answer carries no payload and every unresponsive engine failed transiently (a timeout, a CAPTCHA/429/403 block, a suspension, or a bad Tor circuit's proxy/connection/network/protocol error).
- **Canonical Tooling**: Natively advertises `firecrawl_search`, `firecrawl_scrape`, and `firecrawl_map` tools with clean, flat JSON schemas (every property a scalar or an array of scalars, no combinators; integral parameters typed `integer`) compatible with llama.cpp grammar compilers.
- **Cross-Agent Registration (`users/home/mcp.nix`)**: Declared once on `yifuwuqi` in Home Manager's `programs.mcp.servers.firecrawl` (emitting `~/.config/mcp/mcp.json`) and consumed declaratively via native `enableMcpIntegration` by OpenCode, Antigravity (`~/.gemini/config/mcp_config.json`), and Claude Code (`~/.claude/skills/claude-code-home-manager/.mcp.json`), plus `~/.cursor/mcp.json` linked directly to the generated `mcp.json`.

______________________________________________________________________

## 6. Key Source Files

- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/sd-cpp.nix`
- `modules/services/ai/models.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/opencode.nix`
- `users/home/mcp.nix`
- `users/programs/opencode.nix`
- `packages/firecrawl-mcp/default.nix`
- `packages/firecrawl-mcp/firecrawl-mcp.ts`
- `hosts/yifuwuqi/services.nix`
- `hosts/yitaishi/services.nix`
