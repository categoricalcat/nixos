# Plan: OpenCode research agent on local llama.cpp/Vulkan (Ollama out)

Status: **executed and validated** (2026-07-28), incl. follow-up cleanup:
router removed after the nginx body-routing root cause was found, Ollama
removed from ALL hosts (yitaishi models dark until its llama-cpp/rocm
migration), and the npx firecrawl-mcp + rename shim replaced by a
zero-dependency own MCP server (`users/programs/firecrawl-mcp.js`).

## Objective

Research agent that reliably calls `firecrawl_search` via **local GPU inference**
on yifuwuqi, with a simple architecture: each host serves its own models as plain
per-model `llama-server` units, and clients address them directly (OpenCode
splits providers by `targetHost`) — no router, no shared RPC layer-splitting.

## Root causes established (2026-07-26/28 debugging session)

1. **MCP tool-name mismatch (primary, fixed in working tree).** OpenCode registers
   MCP tools as `<server>_<tool>`. Server `firecrawl` + tool `firecrawl_search`
   became `firecrawl_firecrawl_search`; the agent's gate allowed only
   `firecrawl_search`/`firecrawl_scrape`, which matched nothing → OpenCode sent
   **zero tools** → every model narrated fake tool use. Confirmed by tap-proxying
   the live request (`tools: []`).
2. **Doubled names are unusable even when enabled.** With
   `firecrawl_firecrawl_search` in the schema, qwen2.5:7b and llama3.1:8b both
   emit the *canonical* `firecrawl_search` from training priors; the call fails
   name validation and is silently dropped (empty content, ~46 wasted tokens).
3. **ROCm on the 680M corrupts long prompts (unfixable here).** gfx1030 binaries
   forced onto gfx1035 (`HSA_OVERRIDE_GFX_VERSION=10.3.0`) produce token salad
   once prompts exceed ~4–5k tokens: qwen2.5:7b and llama3.1:8b at 8k/16k/32k
   ctx, fresh blobs, `num_batch` 256–1024, q8 KV — all salad; FA-off crashes
   outright (`CUBLAS_STATUS_INTERNAL_ERROR`); qwen2.5-coder:7b alone stayed
   coherent (but cannot emit `<tool_call>` wrappers at all). Ollama ships no
   Vulkan runner (verified: only CPU + ROCm backends in the package).
4. **llama.cpp grammar compiler chokes on firecrawl's upstream schemas**
   ("number of repetitions exceeds sane defaults") — the nested `scrapeOptions`
   tree is too large. Stripped schemas pass.

## Validated working chain (2026-07-28)

Real OpenCode system prompt (~6k tokens) → llama-server (nixpkgs llama-cpp
b10121, `vulkanSupport = true`, cached binary) on
`Vulkan0 : AMD Radeon 680M (RADV REMBRANDT)` @ 32k ctx → structured
`firecrawl_search` tool call with correct arguments, using:

- a stdio **MCP shim** that re-advertises `firecrawl_search`/`firecrawl_scrape`
  as bare `search`/`scrape`, so OpenCode registers the canonical names;
- **stripped tool schemas** (small whitelisted fields) in the shim's `tools/list`.

CPU inference (`num_gpu 0` Ollama variant) also produced a perfect call and is
the documented last-resort fallback.

## Changes to apply

### 1. NEW `modules/services/ai/llama-cpp.nix` (~120 lines, only new module)

`services.llama-cpp-node = { enable, backend = "vulkan" | "rocm" }`:

- Reads `models.nix`; for each **enabled** entry with
  `targetHost == config.networking.hostName` **and** a `port` field, creates one
  systemd unit `llama-cpp-<sanitized-name>`.
- Package: `pkgs.llama-cpp.override { vulkanSupport = true; }` (binary already
  in the local store). Minimal `rocmSupport` branch reserved for yitaishi later.
- Unit: `llama-server -hf <hfRepo>:<quant> --host 127.0.0.1 --port <port>
  -ngl 99 -fa on --cache-type-k q8_0 --cache-type-v q8_0 --jinja
  -c <contextLength> --no-webui` — the old design's proven flag set; HF GGUF is
  pulled on first start (`Environment LLAMA_CACHE=/var/cache/llama-cpp`,
  `CacheDirectory = "llama-cpp"`).
- Light sandboxing only: `DynamicUser = true`,
  `SupplementaryGroups = [ "video" "render" ]`, `Restart = on-failure`. No
  RPC/device-cgroup gymnastics. (Fallback if the GPU is invisible inside the
  unit: the old report's `DeviceAllow` for `/dev/dri/card0`,
  `/dev/dri/renderD128` + `PrivateDevices = false`.)
- Sets `hardware.graphics.enable = true` (registers the RADV ICD under
  /run/opengl-driver — currently absent on this host; the manual validation used
  a nix-store mesa ICD via `VK_DRIVER_FILES`).

### 2. `modules/services/ai/models.nix` (registry stays)

- Entries may carry optional `port` = llama-server port on their targetHost.
- `qwen2.5:7b`: add `port = 11436`, `contextLength` back to `32768` (the 4096
  was an Ollama-ROCm artifact).
- Remove the `qwen2.5-cpu:7b` entry (CPU detour superseded by Vulkan).
- `enable = false` + comment for yifuwuqi-targeted entries nothing will serve
  once Ollama is gone: `qwen2.5-coder:7b`, `glm4:latest`, `kimi-k2.7:code-7b`,
  `qwen3.5:4b` (re-enable by adding a llama-server unit later). yitaishi-targeted
  entries untouched.

### 3. `modules/services/ai/router.nix` (one logic line)

`targetUrl` uses `m.port or 11435` on both branches (`http://127.0.0.1:<port>`
local, `http://<yitaishi-ip>:<port>` remote). Everything else unchanged.

**Amendment (2026-07-28, post-switch debugging): ROUTER REMOVED.** The
map-on-`$request_body` router never actually routed. nginx evaluates a
*variable* `proxy_pass` **before** reading the request body, so the map
always saw an empty body and every request fell to the default backend —
masquerading as "working" while Ollama answered on 11435, then 502ing
everything once Ollama left. A double-hop fix (static first hop →
`X-Accel-Redirect: /route` → variable `proxy_pass` with `proxy_method
$orig_method` to undo the redirect's POST→GET downgrade) was validated in a
scratch nginx, but the user decided the router should not exist at all: it
only ever stood in for llama-swap's single-endpoint role, and clients can
address the per-model units directly. `modules/services/ai/router.nix` is
deleted, the `services.ai-router` block and import are out of
`hosts/yifuwuqi/services.nix`, and OpenCode instead splits providers by
`targetHost` (`local` → `127.0.0.1:11436`, `yitaishi` →
`100.69.0.4:11434`). The nginx body-routing pitfall above is worth
remembering for any future gateway attempt.

### 4. `modules/services/ai/node.nix` — revert the session's edits

Back to the original (`OLLAMA_IGPU_ENABLE` only; no `OLLAMA_CONTEXT_LENGTH`, no
`cpuModels` option/unit). The file stays for **yitaishi**, which keeps its
Ollama untouched this round.

### 5. `hosts/yifuwuqi/services.nix`

- Remove the `modules/services/ai/node.nix` import and the whole
  `services.ai-node` block (incl. the `cpuModels` detour) — Ollama leaves
  yifuwuqi.
- Import `modules/services/ai/llama-cpp.nix`;
  `services.llama-cpp-node = { enable = true; backend = "vulkan"; };`.
- ~~`services.ai-router` and its import stay as-is.~~ Superseded: the router
  was removed entirely (see §3 amendment).

### 6. `users/programs/opencode.nix`

- Research model → `local/qwen2.5:7b` (provider `local` points at :11436;
  providers are split by `targetHost`, no router — see §3 amendment).
- Shim v2 (already in working tree, needs the schema-strip added): rename
  (`search`/`scrape` ↔ `firecrawl_search`/`firecrawl_scrape`) **and** strip
  advertised schemas to whitelisted simple fields — search: `query`, `limit`,
  `sources[type enum]`; scrape: `url`, `formats[enum]`, `onlyMainContent`.
- Research agent gate stays **search-only** (proven fast path). Scrape stays
  advertised for other agents (DeepSeek handles any schema). Re-adding scrape to
  the research gate is a follow-up once e2e is green.
- Keep `timeout = 30000`, clean-name gates/permissions.

### 7. Leave alone

Staged deletion of `llama-swap.nix` stays staged. yitaishi config untouched.
`/var/lib/ollama` state left on disk (optional manual purge later). Stray repo
files (`output.json`, `test-mcp.js`) flagged, not touched.

## Rebuild & verify

1. `nix build --dry-run .#nixosConfigurations.yifuwuqi.config.system.build.toplevel`
2. `sudo nixos-rebuild switch --flake .#yifuwuqi`
3. `systemctl status 'llama-cpp-*'`; journal shows `Vulkan0 : AMD Radeon 680M`
   and layer offload; first request triggers a one-time 4.7 GB HF pull into
   `/var/cache/llama-cpp`.
4. Server probe: `curl :11436/v1/chat/completions` with `model=qwen2.5:7b` + the
   firecrawl_search tool definition → structured `tool_calls`. (Was "router
   probe" on :11434 before the router was removed — done 2026-07-28 through
   the validated double-hop conf, then re-verified directly.)
5. Live e2e (acceptance): `opencode run --agent research "find top 6 latest
   news in brazil as of the last week, include the timestamp and link for each
   news."` → real MCP call, real news with timestamps/links.
   **Result (2026-07-28): mechanism green across two runs** — the agent
   reliably emits a real `firecrawl_search` MCP call with sane arguments
   (`{"query":"latest news brazil","limit":6,"sources":[{"type":"news"}]}`)
   via the Vulkan unit, no router. Content quality is the remaining gap, and
   it is not plumbing: searxng returns stale hits for the generic query the
   7B model formulates, and the model skips timestamps in the writeup.
   Follow-ups: consider re-adding `tbs` (time-range filter) to the shim's
   stripped search schema, or date hints in the agent prompt.
   **Resolution (2026-07-28, later):** `tbs`/`sources` are accepted but
   *ignored* by self-hosted firecrawl `/v2/search` (verified by probe) — dead
   end. What worked: (a) research-agent `prompt` with strict query rules
   (short keywords, month+year instead of relative-date words, no
   quotes/operators, refine if results >14 days old, never invent dates);
   (b) searxng engine prune (google cse/google news = CAPTCHA-prone portal
   SEO; brave/brave news = worst Tor timeouts; wikinews = 2009-era articles
   ranking top); (c) searxng `request_timeout` 8→12s (all engines hit the 8s
   cap through Tor). Result: 4/6 real current-week news stories with links.
   **Remaining gap:** firecrawl's `/v2/search` strips `publishedDate` (only
   url/title/description survive), so the agent can only report dates found
   in URLs/descriptions. Options: a direct-searxng MCP tool in the shim
   (returns publishedDate), or re-adding scrape to the research gate for
   date verification.

## Fallbacks (in order)

- **Unit can't see the GPU**: apply the old APU report's sandbox fix (explicit
  `DeviceAllow` for the DRM nodes, `PrivateDevices = false`).
- **Vulkan misbehaves**: CPU inference is a *testing/debugging tool only* — per
  user decision (2026-07-28) no CPU-pinned models exist in the declarative
  config. The `num_gpu 0` recipe (validated this session) may be used ad-hoc for
  diagnosis, never as a deployed unit.
- **Scrape wanted in research later**: re-add `firecrawl_scrape` to the agent
  gate after confirming the stripped scrape schema in e2e.

## Security finding (separate follow-up)

`opencode serve` (modules/services/opencode.nix) binds `0.0.0.0:3010` with no
auth, and its `/config` endpoint returns the **resolved DeepSeek API key in
plaintext** (observed live this session). Recommend rotating the key and binding
to localhost or tailnet-only.

## Note on the working tree at time of writing

The tree currently holds the *intermediate* session edits (MCP shim + clean
names in `opencode.nix`/`opencode-rules.md` — keep those; plus the CPU detour:
`cpuModels` in node.nix/services.nix, `qwen2.5-cpu:7b` in models.nix,
`OLLAMA_CONTEXT_LENGTH=4096` — revert those per §4/§5). Executing this plan
means: keep the shim work, drop the CPU detour, add the Vulkan serving layer.
