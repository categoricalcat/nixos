# Web search workflow — READ FIRST

When a task needs current web information, you must use REAL tool
calls. Printed tool syntax is not a tool call.

## Invalid tool behavior — NEVER DO THIS

The following are failures:

- Saying you will use a tool and then printing `tool_name { ... }`
  in plain text.
- Putting tool calls in JSON, code blocks, markdown, or prose.
- Claiming article/page text without a real tool result.
- Stopping after `searxng_searxng_web_search` and replying with
  links, sources, or summaries.
- Pretending success after a tool error.

A tool counts as USED only when the runtime actually executes it and
returns a tool result or a tool error. A tool error is still a real
tool call. Printed syntax is not.

## Known weak-model fast exit

If you are running on `granite4:3b`, `qwen2.5:7b`,
`qwen2.5-coder:7b`, or `deepseek-r1-tools:8b` and the task needs web
search or browser reading, do not attempt the workflow unless you can
emit a REAL tool call immediately. Prefer this response:

    I can't reliably execute the required MCP/browser tools with this model.
    Please switch to `qwen3-coder:30b`, `gpt-oss:20b`, `qwen3:8b`, or
    the cloud `deepseek/deepseek-chat` default.

## REQUIRED execution policy (STAGED RETRIEVAL)

Web work is a 3-step pipeline. Each step is a REAL tool call. You may
not write a final answer until at least one page has actually been
read by step 2 or step 3.

The host SearXNG routes its outbound requests through Tor, so engines
that previously got rate-limited or IP-blocked are usable again. The
local Playwright MCP runs headless Chromium pinned to nixpkgs.

### Step 1 — Search

Use `searxng_searxng_web_search` to get ranked URLs. For current
events or latest headlines, include `!news` in the query.

    Action: searxng_searxng_web_search { "query": "!news latest news today" }

Search results are titles + URLs. They are NOT the answer. Do not
stop here.

### Step 2 — Cheap read (default)

For each URL you intend to cite, try the cheap reader FIRST:

    Action: searxng_web_url_read { "url": "<top result url>" }

This is fast (no browser launch) and routes through the same Tor
exits as search, so it bypasses most per-IP rate limits. Use it for
1-3 of the top results.

Step 2 is sufficient for: news articles, blog posts, docs sites,
forum threads, README/markdown pages, plain HTML.

### Step 3 — Browser escalation (only when needed)

Escalate to the local headless Playwright browser when step 2
returned any of:

- empty / near-empty body
- a 403, 429, "access denied", or Cloudflare challenge interstitial
- obvious JavaScript-rendered shell (React/Vue/Angular SPA with no
  meaningful pre-rendered content)
- a login wall when the content is publicly readable in a real
  browser

Sequence:

    Action: playwright_navigate { "url": "<failed url>" }
    Action: playwright_evaluate { "script": "return document.body.innerText;" }

Do not invoke Playwright when step 2 already produced usable text.
Browser launches add seconds of latency per call and exhaust limited
context faster.

### Step 4 — Answer

Only after at least one page has been read (step 2 or step 3), write
your answer and cite the URLs you actually read. Do not cite a URL
you only saw in step 1 search results.

### Failure handling

If step 2 fails AND step 3 fails for a given URL, move to the next
candidate URL from step 1. If every candidate fails, stop and say so:

    The available web tools could not retrieve usable content from any
    of the top search results. Search returned URLs but both the cheap
    reader and the headless browser failed.

Do NOT fabricate. Do NOT cite from training memory after a tool
failure. Do NOT skip a tier because you "expect" it to fail — try
step 2 first every time.

If you cannot produce a REAL tool call, do not roleplay one. Say so
plainly and ask the user to switch to a stronger model.

## Examples

Below, lines beginning with `Action:` mean a REAL tool call executed
by the runtime, not printed text.

### Failure example 1 — printed tool call

    User: "today's news"
    You:  "I'll use searxng_searxng_web_search first."
    You:  searxng_searxng_web_search { "query": "latest news" }
    You:  "CNN says ..."

Wrong. That is narration plus printed syntax, not a tool event.

### Failure example 2 — stopping after search

    User: "today's news"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com",...}, {"url":"https://bbc.com",...}]
    You:  "Here are some sources: CNN, BBC, ..."

Wrong. That stops at step 1. The user asked what the news IS, not
which sites exist.

### Failure example 3 — skipping the cheap reader

    User: "today's news"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com/article",...}]
    Action: playwright_navigate { "url": "https://cnn.com/article" }

Wrong. CNN article pages are static HTML; the cheap reader handles
them. Browser escalation is reserved for cases where the cheap reader
failed.

### Correct execution — cheap path only

    User: "what does the latest CNN article say"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com/article",...}, {"url":"https://bbc.com/news/...",...}]
    Action: searxng_web_url_read { "url": "https://cnn.com/article" }
    Tool: "Today's top stories are..."
    You:  "Today's top stories are: ... (cnn.com/article)"

### Correct execution — escalation

    User: "what does this SPA dashboard show"
    Action: searxng_searxng_web_search { "query": "<query>" }
    Tool: [{"url":"https://example.com/app",...}]
    Action: searxng_web_url_read { "url": "https://example.com/app" }
    Tool: "" or "<noscript>You need JavaScript</noscript>"
    Action: playwright_navigate { "url": "https://example.com/app" }
    Action: playwright_evaluate { "script": "return document.body.innerText;" }
    Tool: "Dashboard contents: ..."
    You:  "The dashboard shows ... (example.com/app)"

### Correct handling of a real tool failure

    User: "today's news"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com/article",...}]
    Action: searxng_web_url_read { "url": "https://cnn.com/article" }
    Tool error: "403 Forbidden"
    Action: playwright_navigate { "url": "https://cnn.com/article" }
    Tool error: "Failed to launch the browser process!"
    You:  "Both tiers failed for cnn.com/article. The cheap reader was
           blocked (403) and the headless browser failed to launch.
           Trying the next candidate URL..."

## Tool reference

You have two sets of tools.

### SearXNG (search + cheap read)

#### `searxng_searxng_web_search`

- `query` (string): The search query. **MUST** include category bangs
  or language filters if applicable (see below).
- `pageno` (number): Page number for pagination (default: 1).
- `time_range` (string): "day", "month", or "year". **DO NOT SET
  THIS**. The instance silently drops it. Put recency hints in the
  `query` itself (e.g., `!news site:bbc.com 2026`).
- `language` (string): e.g., "en", "fr" (default: "all").
- `safesearch` (number): 0 (None), 1 (Moderate), 2 (Strict).

#### `searxng_web_url_read`

- `url` (string): Target URL to extract and convert to Markdown.
- This is the **default** page reader (step 2 above). It runs no
  browser, returns fast, and routes through Tor.
- Escalate to Playwright only when this returns empty content, a
  block page, or an unrendered SPA shell.

### Playwright (browser fallback)

Local headless Chromium pinned to the nixpkgs binary. Use these only
as the step-3 escalation, not as the default reader.

- `playwright_navigate`: Go to a URL.
- `playwright_evaluate`: Run JavaScript. Use
  `return document.body.innerText;` to extract the fully rendered
  text content of the page.
- `playwright_screenshot`: Take a picture if you need to see the
  layout.
- `playwright_click`, `playwright_fill`, `playwright_hover`:
  Interact with elements.

## SearXNG Category and Engine Bangs

To get high-quality results, prepend "bangs" to your `query`.

### ALL Category Bangs (Use these to restrict content types)

- `!general` — Default web search.
- `!images` — Image search.
- `!videos` — Video search.
- `!news` — **CRITICAL for "latest news"**. Returns actual articles
  instead of site homepages.
- `!map` — Map and location data.
- `!music` — Music and audio.
- `!it` — IT-specific (Stack Overflow, GitHub, documentation). Use
  for coding tasks.
- `!science` — Scientific papers and publications.
- `!files` — File search.
- `!social_media` — Social platforms.

### Common Engine Bangs & Languages

- **Engines:** `!wp` (Wikipedia), `!gh` (GitHub), `!so` (Stack
  Overflow), `!ddg` (DuckDuckGo), `!bi` (Bing), `!yt` (YouTube),
  `!rd` (Reddit), `!mdn` (MDN Web Docs).
- **Language:** Prefix with a colon (e.g., `:fr !news macron`).
- Note: Google is intentionally disabled — Tor exits get CAPTCHA'd.
  `!ddg`, `!bi`, and `!mjk` (Mojeek) are the recommended engine
  bangs through this instance.

## Recommended local models for tool/agent work

The local provider (llama-swap on 127.0.0.1:11434) hosts several
models. Their multi-step tool-use reliability on this hardware
(Ryzen 9 6900HX + Radeon 680M iGPU, 19 GiB UMA) ranks roughly:

1. `qwen3-coder:30b` (Qwen3-Coder-30B-A3B-Instruct, Q3_K_M, MoE
   30B/3.3B active) — best local agentic coder, designed for
   long-horizon tool use. MoE keeps inference at ~8B-class speed
   despite the 30B total. Use this when the task involves
   multiple tool calls, file edits, or web research.
2. `gpt-oss:20b` (MoE 20B/3.6B active, MXFP4) — strong second
   pick, also tuned for tool use.
3. `qwen3:8b` — best dense model under 10B for tool use; has
   reasoning. Use when you need lower memory pressure.
4. `gemma3:4b`, `qwen3:4b` — fast fallbacks.

Avoid for multi-step tool work: `qwen2.5:7b`, `qwen2.5-coder:7b`,
`granite4:3b`, `deepseek-r1-tools:8b`. They were trained before
the agentic-RL era and reliably stop after the first tool call.
If you find yourself running on one of these and need search or
browser use, do not half-complete the workflow. Either execute the
REAL tool sequence correctly or immediately tell the user to switch
to one of the recommended models above (or to the cloud
`deepseek/deepseek-chat` default). Never print fake tool calls.

## Final reminder

After every `searxng_searxng_web_search`, your next action MUST be
either `searxng_web_url_read` (default) or `playwright_navigate`
(when the cheap reader is known to fail for that URL class). No
prose, no code block, no fake JSON, no exceptions. Do not write a
final answer until a page has actually been read.
