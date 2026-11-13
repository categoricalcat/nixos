# AI & Local Inference Infrastructure

This document details the self-hosted LLM inference stack, Vulkan acceleration, declarative model registry, router-mode serving, agent tooling, and companion web interfaces.

______________________________________________________________________

## 1. Inference Topology

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                     yifuwuqi (24/7 Core Server)                         │
│  AMD Ryzen 9 6900HX · Radeon 680M APU (4 GiB VRAM + 9.65 GiB GTT)       │
│  llama-cpp.service (Vulkan RADV · 127.0.0.1:11436 · --models-max 1)     │
│   ├─ gemma-4-12b             (UD-Q4_K_XL · 32k ctx · thinking on)       │
│   └─ gemma-4-12b-uncensored  (Q4_K_M     · 32k ctx · thinking off)      │
└───────────────────┬───────────────────────────────┬─────────────────────┘
                    │ loopback                      │ loopback
                    ▼                               ▼
         ┌────────────────────┐          ┌────────────────────┐
         │ SillyTavern UI     │          │ Opencode Agent     │
         │ (:24000 Web UI)    │          │ (:24010 / CLI)     │
         └────────────────────┘          └──────────┬─────────┘
                                                    │ Tailscale (100.69.0.4:11436)
                                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     yitaishi (24 GiB Workstation)                       │
│  AMD Ryzen 7 7700X · Radeon RX 7900 XTX (24 GiB GDDR6 · gfx1100)        │
│  llama-cpp.service (Vulkan RADV · 127.0.0.1,100.69.0.4:11436 · max 1)   │
│   ├─ qwen3.8-27b             (UD-Q4_K_XL · 64k ctx · thinking on)       │
│   └─ qwen3.8-27b-uncensored  (UD-Q4_K_XL · 64k ctx · thinking on)       │
└─────────────────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Router-Mode Model Serving (`modules/services/ai/llama-cpp.nix`)

- **Vulkan Backend**: Configured via `services.llama-cpp-node.backend = "vulkan"` (`rocmSupport = false` explicitly so hosts with global `nixpkgs.config.rocmSupport = true` reuse the cached Vulkan-only `llama-cpp` build). Uses Vulkan compute rather than ROCm on the Ryzen 680M APU because ROCm (`gfx1030` binaries forced onto `gfx1035`) corrupts memory beyond ~4–5k tokens.
- **Native Router Mode (`--models-preset` + `--models-max 1`)**: Each host runs a single `llama-cpp.service` router on port `11436` (`modules/addresses.nix`). The router starts in `<0.1s` with `0 MiB` GPU memory allocated, loads models on demand when requested by model ID, and LRU-evicts any loaded model before spawning the alternate preset so two models can never simultaneously OOM VRAM/GTT.
- **Preset Optimizations**: Child instances inherit `-ngl 99`, `--split-mode none` (preventing tensor splits onto `yitaishi`'s `512 MiB` `gfx1036` iGPU), `-fa on` (FlashAttention), `--cache-type-k q8_0 --cache-type-v q8_0`, `--parallel 1`, `--jinja`, `--no-mmproj`, and `--sleep-idle-seconds 300`.
- **Network Binding**: Loopback-only (`127.0.0.1:11436`) on `yifuwuqi`; loopback plus Tailscale (`127.0.0.1,100.69.0.4:11436`, firewall-scoped to `tailscale0`) on `yitaishi`.

______________________________________________________________________

## 3. Central Model Registry (`modules/services/ai/models.nix`)

`models.nix` declares two hardware-sized models per host (one censored, one Heretic-abliterated uncensored):

| Model ID                 | Target Host | Port    | Context | Quantization | Source Repository                          | Tools / Reasoning          |
| ------------------------ | ----------- | ------- | ------- | ------------ | ------------------------------------------ | -------------------------- |
| `gemma-4-12b`            | `yifuwuqi`  | `11436` | `32768` | `UD-Q4_K_XL` | `unsloth/gemma-4-12b-it-GGUF`              | Tools: Yes, Reasoning: Yes |
| `gemma-4-12b-uncensored` | `yifuwuqi`  | `11436` | `32768` | `Q4_K_M`     | `zaakirio/gemma-4-12b-it-uncensored-GGUF`  | Tools: Yes, Reasoning: No  |
| `qwen3.8-27b`            | `yitaishi`  | `11436` | `65536` | `UD-Q4_K_XL` | `unsloth/Qwen3.8-27B-GGUF`                 | Tools: Yes, Reasoning: Yes |
| `qwen3.8-27b-uncensored` | `yitaishi`  | `11436` | `65536` | `UD-Q4_K_XL` | `ajgazin/Qwen3.8-27B-Heretic-Dynamic-GGUF` | Tools: Yes, Reasoning: Yes |

______________________________________________________________________

## 4. AI Client Ecosystem & Web Interfaces

### 4.1 SillyTavern Companion (`modules/services/ai/sillytavern.nix`)

- **Domain**: `https://companion.aset.love` (proxied to port `24000`).
- **Security**: Strict systemd isolation under dedicated user `sillytavern`, ordered after `llama-cpp.service`. The API endpoint (`http://127.0.0.1:11436/v1`) and model are selected in the SillyTavern UI, not by the module.

### 4.2 Opencode Agent (`modules/services/opencode.nix`, `users/programs/opencode.nix`)

- **Domain**: `https://agent.aset.love` (proxied to port `24010`).
- **Providers**: Exposes `deepseek` and `yitaishi` (`127.0.0.1:11436` on `yitaishi`, `100.69.0.4:11436` over Tailscale elsewhere) everywhere, plus `local` (`127.0.0.1:11436`) only on `yifuwuqi`, whose router is loopback-only. The `research` agent defaults to `local/gemma-4-12b` on `yifuwuqi` and `yitaishi/qwen3.8-27b` elsewhere.

### 4.3 Firecrawl MCP Server (`users/programs/firecrawl-mcp.js`)

- **Zero-Dependency Stdio Bridge**: Custom MCP server interfacing with the self-hosted Firecrawl instance.
- **Canonical Tooling**: Natively advertises `firecrawl_search` and `firecrawl_scrape` tools with clean, flat JSON schemas compatible with llama.cpp grammar compilers.

______________________________________________________________________

## 5. Key Source Files

- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/models.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/opencode.nix`
- `users/programs/opencode.nix`
- `users/programs/firecrawl-mcp.js`
- `hosts/yifuwuqi/services.nix`
- `hosts/yitaishi/services.nix`
