# AI & Local Inference Infrastructure

This document details the self-hosted LLM inference stack, Vulkan acceleration, declarative model registry, router-mode serving, agent tooling, and companion web interfaces.

______________________________________________________________________

## 1. Inference Topology

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                     yifuwuqi (24/7 Core Server)                         │
│  AMD Ryzen 9 6900HX · Radeon 680M APU (4 GiB VRAM + 9.65 GiB GTT)       │
│  llama-cpp.service (Vulkan RADV · 127.0.0.1:11436 · --models-max 1)     │
│   ├─ gemma-4-12b             (UD-Q4_K_XL · 64k ctx · thinking on)       │
│   └─ gemma-4-12b-uncensored  (Q4_K_M     · 64k ctx · thinking on)       │
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
│   ├─ qwen3.8-27b             (UD-Q4_K_XL · 96k ctx · thinking on)       │
│   └─ qwen3.8-27b-uncensored  (UD-Q4_K_XL · 96k ctx · thinking on)       │
│  sd-cpp.service (Vulkan RADV · 0.0.0.0:11437 · tailscale0 + localhost)  │
│   └─ chroma1-hd              (Q8_0 · 1024x1024 · --offload-to-cpu)      │
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

`models.nix` declares two hardware-sized LLM models per host (one censored, one Heretic-abliterated uncensored) plus the uncensored `chroma1-hd` diffusion model on `yitaishi`:

| Model ID                 | Target Host | Port    | Context / Resolution | Quantization | Source Repository                          | Notes                      |
| ------------------------ | ----------- | ------- | -------------------- | ------------ | ------------------------------------------ | -------------------------- |
| `gemma-4-12b`            | `yifuwuqi`  | `11436` | `65536`              | `UD-Q4_K_XL` | `unsloth/gemma-4-12b-it-GGUF`              | Tools: Yes, Reasoning: Yes |
| `gemma-4-12b-uncensored` | `yifuwuqi`  | `11436` | `65536`              | `Q4_K_M`     | `zaakirio/gemma-4-12b-it-uncensored-GGUF`  | Tools: Yes, Reasoning: Yes |
| `qwen3.8-27b`            | `yitaishi`  | `11436` | `98304`              | `UD-Q4_K_XL` | `unsloth/Qwen3.8-27B-GGUF`                 | Tools: Yes, Reasoning: Yes |
| `qwen3.8-27b-uncensored` | `yitaishi`  | `11436` | `98304`              | `UD-Q4_K_XL` | `ajgazin/Qwen3.8-27B-Heretic-Dynamic-GGUF` | Tools: Yes, Reasoning: Yes |
| `chroma1-hd`             | `yitaishi`  | `11437` | `1024x1024`          | `Q8_0`       | `silveroxides/Chroma1-HD-GGUF`             | Uncensored 8.9B Flux DiT   |

______________________________________________________________________

## 4. Uncensored Image Generation (`modules/services/ai/sd-cpp.nix`)

- **Engine (`pkgs.stable-diffusion-cpp`)**: Runs `sd-server` built with `vulkanSupport = true` and `rocmSupport = false`, pinned to `--backend vulkan0` on `yitaishi`'s RX 7900 XTX (`24 GiB` VRAM).
- **Native Web UI**: Builds the frontend pinned inside the same stable-diffusion.cpp source and serves it at `https://image.aset.love` through yirukou (`http://100.69.0.4:11437/` over Tailscale). It exposes exact prompts, seeds, dimensions, guidance, init/reference/mask/control images, high-resolution passes, previews, and cancellation without loading another model server.
- **VRAM Coexistence (`--offload-to-cpu`)**: Keeps source parameters in host RAM, prefetches and caches GPU replicas while sampling, then reclaims them after the request so `qwen3.8-27b-uncensored` can load later. A 1024x1024 probe held the RX 7900 XTX at 100% utilization and 350–392 W with about 12 GiB total VRAM in use; idle usage returned to about 2 GiB.
- **Verified Cache (`sd-cpp-fetch`)**: A background service verifies every artifact against its pinned SHA256 digest, downloading missing or mismatched weights into `/var/cache/sd-cpp` before starting `sd-server` without delaying activation.
- **Network Scope**: Listens on port `11437`, restricted by systemd `IPAddressAllow = [ "localhost" "100.64.0.0/10" ]` and `yitaishi`'s `tailscale0` firewall rule.

______________________________________________________________________

## 5. AI Client Ecosystem & Web Interfaces

### 5.1 SillyTavern Companion (`modules/services/ai/sillytavern.nix`)

- **Domain**: `https://companion.aset.love` (proxied to port `24000`).
- **Security**: Strict systemd isolation under dedicated user `sillytavern`, ordered after `llama-cpp.service`. The LLM endpoint (`http://127.0.0.1:11436/v1` or `http://100.69.0.4:11436/v1`) and model are selected in the SillyTavern UI.
- **Image Generation**: Connect the built-in **Image Generation** extension to `yitaishi` by selecting **Source**: `stable-diffusion.cpp` (not `AUTOMATIC1111 / SD WebUI`), **Server URL**: `http://100.69.0.4:11437`, **Sampler**: `euler`, **CFG Scale**: `3.5`, **Steps**: `20`, and **Resolution**: `1024x1024`.
- **Manual Prompts**: Enable **Edit prompts before generation**, or use `/imagine extend=false edit=true seed=1234 width=1024 height=1024 steps=20 cfg=3.5 <prompt>`.
- **Text-Only Local Models**: Disable **Send inline media** in Chat Completion settings. SillyTavern assumes custom OpenAI-compatible endpoints accept images, but the local Qwen models have no multimodal projector and reject attached images with HTTP 500.

### 5.2 Opencode Agent (`modules/services/opencode.nix`, `users/programs/opencode.nix`)

- **Domain**: `https://agent.aset.love` (proxied to port `24010`).
- **Providers**: Exposes `deepseek` and `yitaishi` (`127.0.0.1:11436` on `yitaishi`, `100.69.0.4:11436` over Tailscale elsewhere) everywhere, plus `local` (`127.0.0.1:11436`) only on `yifuwuqi`, whose router is loopback-only. The Firecrawl MCP is registered only on `yifuwuqi`, where the Firecrawl API listens on `localhost:24002`; its tools are wired into the `research` (web-only lockdown), `build`, and `plan` agents there. Other hosts use the built-in default agent (remote Firecrawl use goes via `ssh`).

### 5.3 Firecrawl MCP Server (`packages/firecrawl-mcp`)

- **Strictly-Type-Checked Stdio Bridge**: Custom MCP server — strictest-`tsc` type-checked at build, zero runtime dependencies (Node native type stripping), registered only on `yifuwuqi`. `scrape` targets the self-hosted Firecrawl API; `search` targets the local SearXNG JSON API (`localhost:24888`) with a 1:1 param mapping (categories, engines, language, time_range, pageno, safesearch) — Firecrawl's searxng adapter drops date filters and pins categories via env, so per-request filters are impossible through Firecrawl.
- **Canonical Tooling**: Natively advertises `firecrawl_search` and `firecrawl_scrape` tools with clean, flat JSON schemas compatible with llama.cpp grammar compilers.

______________________________________________________________________

## 6. Key Source Files

- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/sd-cpp.nix`
- `modules/services/ai/models.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/opencode.nix`
- `users/programs/opencode.nix`
- `packages/firecrawl-mcp/default.nix`
- `packages/firecrawl-mcp/firecrawl-mcp.ts`
- `hosts/yifuwuqi/services.nix`
- `hosts/yitaishi/services.nix`
