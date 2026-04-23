# Web search workflow — READ FIRST

When a task needs current web information, you must use REAL tool
calls. Printed tool syntax is not a tool call.

## Invalid tool behavior — NEVER DO THIS

The following are failures:

- Saying you will use a tool and then printing `tool_name { ... }`
  in plain text.
- Putting tool calls in JSON, code blocks, markdown, or prose.
- Claiming article/page text without a real `puppeteer_evaluate`
  result.
- Stopping after `searxng_searxng_web_search` and replying with
  links, sources, or summaries.
- Falling back to `searxng_web_url_read` for page reading. That tool
  is deprecated for this workflow and must not be used as a backup.
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

## REQUIRED execution policy (DIRECT BROWSER)

IF YOU CALL `searxng_searxng_web_search`, YOUR VERY NEXT ACTION
MUST BE AN ACTUAL `puppeteer_navigate` TOOL CALL. STOPPING AFTER A
SEARCH IS A BUG. Search results are only titles + URLs; the page
content is what answers the question.

Step 1 (search):

    For current events or latest headlines, include `!news` in the query.
    Example:
    searxng_searxng_web_search { "query": "!news latest news today" }

Step 2 (read — MANDATORY before any text reply):

    You MUST use your local Puppeteer browser to read pages. This is the only way to reliably bypass anti-bot screens and regional blocks.

    1. Call `puppeteer_navigate { "url": "<top result url>" }`
    2. Call `puppeteer_evaluate { "script": "return document.body.innerText;" }`

Repeat step 2 for the top 1-3 most relevant URLs. Only then write
your answer, citing the URLs you actually read.

No text reply is allowed:

- between search and the first `puppeteer_navigate`
- between `puppeteer_navigate` and `puppeteer_evaluate`
- before at least one page has been read

If you cannot produce a REAL tool call, do not roleplay one. Say
so plainly and ask the user to switch to a stronger model instead of
fabricating results.

If `puppeteer_navigate` or `puppeteer_evaluate` fails, stop and say
the browser tool failed. Do NOT fall back to `searxng_web_url_read`,
search-result snippets, memory, or guesses.

Recommended fail-fast wording:

    I can't reliably execute the required MCP/browser tools with this model.
    Please switch to `qwen3-coder:30b`, `gpt-oss:20b`, `qwen3:8b`, or
    the cloud `deepseek/deepseek-chat` default.

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

### Correct execution

    User: "today's news"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com/article",...}, {"url":"https://bbc.com/news/...",...}]
    Action: puppeteer_navigate { "url": "https://cnn.com/article" }
    Tool: <navigation result>
    Action: puppeteer_evaluate { "script": "return document.body.innerText;" }
    Tool: "Today's top stories are..."
    You:  "Today's top stories are: ... (cnn.com/article)"

### Correct handling of a real tool failure

    User: "today's news"
    Action: searxng_searxng_web_search { "query": "!news latest news today" }
    Tool: [{"url":"https://cnn.com/article",...}]
    Action: puppeteer_navigate { "url": "https://cnn.com/article" }
    Tool error: "Failed to launch the browser process!"
    You:  "The browser tool really ran, but it failed locally. I need the browser runtime fixed or a stronger working browser configuration before I can read the page."

Do not continue with `searxng_web_url_read` after a Puppeteer error.
That still violates the workflow.

## SearXNG MCP Tool Calls and Arguments

You have access to two sets of tools.

### SearXNG (Search Only)

#### `searxng_searxng_web_search`

- `query` (string): The search query. **MUST** include category bangs or language filters if applicable (see below).
- `pageno` (number): Page number for pagination (default: 1).
- `time_range` (string): "day", "month", or "year". **DO NOT SET THIS**. The instance silently drops it. Put recency hints in the `query` itself (e.g., `!news site:bbc.com 2026`).
- `language` (string): e.g., "en", "fr" (default: "all").
- `safesearch` (number): 0 (None), 1 (Moderate), 2 (Strict).

#### `searxng_web_url_read`

- `url` (string): Target URL to extract and convert to Markdown.
- **DEPRECATED**: Use Puppeteer instead for all page reading to ensure reliability.
- NEVER use this as a fallback when Puppeteer fails.

### Puppeteer (Primary Web Reader)

You have access to a full local Chrome browser via the following tools. **ALWAYS** use these for reading page content:

- `puppeteer_navigate`: Go to a URL.
- `puppeteer_evaluate`: Run JavaScript. Use `return document.body.innerText;` to extract the fully rendered text content of the page.
- `puppeteer_screenshot`: Take a picture if you need to see the layout.
- `puppeteer_click`, `puppeteer_type`, `puppeteer_hover`: Interact with elements.

## SearXNG Category and Engine Bangs

To get high-quality results, prepend "bangs" to your `query`.

### ALL Category Bangs (Use these to restrict content types)

- `!general` — Default web search.
- `!images` — Image search.
- `!videos` — Video search.
- `!news` — **CRITICAL for "latest news"**. Returns actual articles instead of site homepages.
- `!map` — Map and location data.
- `!music` — Music and audio.
- `!it` — IT-specific (Stack Overflow, GitHub, documentation). Use for coding tasks.
- `!science` — Scientific papers and publications.
- `!files` — File search.
- `!social_media` — Social platforms.

### Common Engine Bangs & Languages

- **Engines:** `!wp` (Wikipedia), `!gh` (GitHub), `!so` (Stack Overflow), `!ddg` (DuckDuckGo), `!go` (Google), `!bi` (Bing), `!yt` (YouTube), `!rd` (Reddit), `!mdn` (MDN Web Docs).
- **Language:** Prefix with a colon (e.g., `:fr !news macron`).

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
an ACTUAL `puppeteer_navigate` tool call. No prose, no code block,
no fake JSON, no exceptions.
