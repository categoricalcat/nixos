# AI And ROCm

This page documents the local inference setup: plain per-model servers, no
routing layer.

## Current Topology

Inference runs directly on the host that owns the model. Each host serves its
own models; clients address the servers directly.

- **`yifuwuqi`**: Hosts lightweight models on its **Radeon 680M APU (~9.6 GB
  UMA)** via `services.llama-cpp-node` (llama.cpp, **Vulkan**) — one
  `llama-cpp-<model>` systemd unit per enabled registry entry that declares a
  `port`, bound to `127.0.0.1:<port>` (currently `qwen2.5:7b` on `11436`).
  Vulkan is used instead of ROCm because ROCm on this APU (gfx1030 binaries
  forced onto gfx1035) corrupts prompts beyond ~4–5k tokens.
- **`yitaishi`**: No serving backend at the moment. Its registry entries
  (`qwen3.6:35b-a3b`, `kimi-k2.7:code`, `glm-4.7-flash:30b`) are
  `enable = false` until it migrates to `services.llama-cpp-node` with the
  `rocm` backend (RX 7900 XTX, gfx1100). Ollama was removed everywhere.

`modules/services/ai/models.nix` is the central registry declaring model
definitions, capabilities, target hosts and ports.

## Serving Module

`modules/services/ai/llama-cpp.nix` (`services.llama-cpp-node { backend =
"vulkan" | "rocm"; }`): reads `models.nix` and spawns one `llama-server` unit
per enabled local model with a `port`. GGUFs are pulled from HuggingFace on
first start into `/var/cache/llama-cpp`.

## Clients

`users/programs/opencode.nix` points provider `local` at yifuwuqi's
llama-server (`http://127.0.0.1:11436/v1`, port derived from the registry).
There is no shared gateway: a previous nginx body-routing attempt
(`map $request_body`) was abandoned — nginx evaluates a variable
`proxy_pass` before reading the request body, so it can never see the model
name.

Web search/scrape for agents comes from the self-hosted Firecrawl instance
via `users/programs/firecrawl-mcp.js` — a zero-dependency MCP stdio server
that natively advertises the canonical `firecrawl_search`/`firecrawl_scrape`
tool names with small whitelisted schemas (upstream `firecrawl-mcp` behind a
rename shim was removed: doubled tool names broke small-model calls and its
nested schemas broke llama.cpp's grammar compiler).
