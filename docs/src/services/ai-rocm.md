# AI & Local Inference Infrastructure

This document details the self-hosted LLM inference stack, Vulkan/ROCm acceleration, model registry architecture, agent tooling, and companion web interfaces.

______________________________________________________________________

## 1. Inference Topology

```text
┌─────────────────────────────────────────────────────────────┐
│                    yifuwuqi (Inference Host)                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ AMD Radeon 680M APU (~9.6 GB UMA)                     │  │
│  │ Backend: Vulkan (RADV) via services.llama-cpp-node    │  │
│  └──────────────────────────┬────────────────────────────┘  │
│                             │                               │
│  ┌──────────────────────────▼────────────────────────────┐  │
│  │ llama-server: qwen3.6-35b-abliterated                 │  │
│  │ • Port: 11437 (127.0.0.1:11437)                       │  │
│  │ • Quantization: IQ2_M (mradermacher)                  │  │
│  │ • Context Window: 16,384 tokens                       │  │
│  │ • Optimizations: FlashAttention, Q8 KV Cache          │  │
│  │ • Idle Sleep: 300 seconds                             │  │
│  └──────────────────────────┬────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌──────────────────┐┌──────────────────┐┌──────────────────┐
│ SillyTavern UI   ││ Opencode Agent   ││ Firecrawl MCP    │
│ (:24000 Web UI)  ││ (:24010 Agent)   ││ (Stdio Scraper)  │
└──────────────────┘└──────────────────┘└──────────────────┘
```

______________________________________________________________________

## 2. Model Serving Module (`modules/services/ai/llama-cpp.nix`)

- **Vulkan Backend**: Configured via `services.llama-cpp-node.backend = "vulkan"`. Uses Vulkan compute rather than ROCm on the Ryzen APU because ROCm (forcing gfx1030 binaries onto gfx1035 hardware) causes memory corruption beyond ~4–5k tokens.
- **On-Demand Execution**: Units intentionally omit `wantedBy = ["multi-user.target"]` to save VRAM and power until explicitly requested by clients.
- **Dynamic Layer Offloading**: Runs with `-ngl 99` (offloading 100% of model layers to GPU), `-fa on` (FlashAttention), and `--cache-type-k q8_0 --cache-type-v q8_0` (high-precision 8-bit KV caching).
- **Idle Power Down**: Automatically sleeps GPU memory after 5 minutes of inactivity (`--sleep-idle-seconds 300`).

______________________________________________________________________

## 3. Central Model Registry (`modules/services/ai/models.nix`)

`models.nix` provides a single declarative specification mapping AI models to hardware targets, context lengths, HuggingFace repositories, and capabilities:

| Model ID                      | Target Host | Port    | Context  | Quantization | Enabled             | Tools / Reasoning          |
| ----------------------------- | ----------- | ------- | -------- | ------------ | ------------------- | -------------------------- |
| **`qwen3.6-35b-abliterated`** | `yifuwuqi`  | `11437` | `16384`  | `IQ2_M`      | **Active (`true`)** | Tools: Yes, Reasoning: Yes |
| `qwen2.5:7b`                  | `yifuwuqi`  | `11436` | `32768`  | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |
| `qwen3.6-35b-a3b`             | `yifuwuqi`  | `11436` | `16384`  | `IQ2_M`      | `false`             | Tools: Yes, Reasoning: Yes |
| `qwen2.5-coder:7b`            | `yifuwuqi`  | `11436` | `65536`  | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |
| `qwen3.5:4b`                  | `yifuwuqi`  | `11436` | `65536`  | `Q8_0`       | `false`             | Tools: Yes, Reasoning: No  |
| `kimi-k2.7:code-7b`           | `yifuwuqi`  | `11436` | `65536`  | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |
| `kimi-k2.7:code`              | `yitaishi`  | `11436` | `65536`  | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |
| `glm4:latest`                 | `yifuwuqi`  | `11436` | `65536`  | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |
| `glm-4.7-flash:30b`           | `yitaishi`  | `11436` | `131072` | `Q4_K_M`     | `false`             | Tools: Yes, Reasoning: Yes |

______________________________________________________________________

## 4. AI Client Ecosystem & Web Interfaces

### 4.1 SillyTavern Companion (`modules/services/ai/sillytavern.nix`)

- **Domain**: `https://sillytavern.fufu.land` (proxied to port `24000`).
- **Security**: Strict systemd isolation under dedicated user `sillytavern`. Pre-start script automatically bootstraps default settings and enables network listening with security overrides.

### 4.2 Opencode Agent Server (`modules/services/opencode.nix`)

- **Domain**: `https://agent.fufu.land` (proxied to port `24010`).
- **Configuration**: Runs as user `yi:yi`, providing a persistent backend for autonomous coding workflows.

### 4.3 Firecrawl MCP Server (`users/programs/firecrawl-mcp.js`)

- **Zero-Dependency Stdio Bridge**: Custom MCP server interfacing with the self-hosted Firecrawl instance.
- **Canonical Tooling**: Natively advertises `firecrawl_search` and `firecrawl_scrape` tools with clean, flat JSON schemas compatible with llama.cpp grammar compilers.

______________________________________________________________________

## 5. Key Source Files

- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/models.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/opencode.nix`
- `users/programs/firecrawl-mcp.js`
- `hosts/yifuwuqi/services.nix`
