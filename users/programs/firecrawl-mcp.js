#!/usr/bin/env node
// Minimal MCP stdio server for the self-hosted Firecrawl instance.
//
// Replaces the npx firecrawl-mcp package + rename shim: upstream advertises
// tools as firecrawl_search/firecrawl_scrape, which OpenCode then doubles to
// firecrawl_firecrawl_* (small models emit the canonical names and their
// calls fail validation), and its deeply-nested schemas break llama.cpp's
// grammar compiler. Here the tools are natively named search/scrape, so
// OpenCode registers exactly firecrawl_search/firecrawl_scrape, with small
// whitelisted schemas that compile.
//
// Zero dependencies: plain node (>=18, global fetch), newline-delimited
// JSON-RPC over stdio.

const API = (process.env.FIRECRAWL_API_URL || "http://localhost:24002").replace(/\/$/, "");

const TOOLS = [
  {
    name: "search",
    description:
      "Search the web. Best for finding current information when you don't know the exact page.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", minLength: 1 },
        limit: { type: "number" },
        sources: {
          type: "array",
          items: {
            type: "object",
            properties: { type: { type: "string", enum: ["web", "images", "news"] } },
            required: ["type"],
          },
        },
      },
      required: ["query"],
      additionalProperties: false,
    },
  },
  {
    name: "scrape",
    description: "Scrape a single URL and return its content as markdown.",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", format: "uri" },
        formats: {
          type: "array",
          items: {
            type: "string",
            enum: ["markdown", "html", "rawHtml", "links", "summary"],
          },
        },
        onlyMainContent: { type: "boolean" },
      },
      required: ["url"],
      additionalProperties: false,
    },
  },
];

async function callApi(path, body) {
  const res = await fetch(`${API}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    throw new Error(json.error || `firecrawl HTTP ${res.status}`);
  }
  return json;
}

function textResult(text) {
  return { content: [{ type: "text", text }] };
}

const handlers = {
  initialize: (params) => ({
    protocolVersion: params?.protocolVersion || "2025-06-18",
    capabilities: { tools: {} },
    serverInfo: { name: "firecrawl", version: "1.0.0" },
  }),

  ping: () => ({}),

  "tools/list": () => ({ tools: TOOLS }),

  "tools/call": async (params) => {
    const { name, arguments: args = {} } = params || {};
    try {
      if (name === "search") {
        const json = await callApi("/v2/search", {
          query: args.query,
          ...(args.limit != null && { limit: args.limit }),
          ...(args.sources != null && { sources: args.sources }),
        });
        return textResult(JSON.stringify(json.data?.web ?? json.data ?? []));
      }
      if (name === "scrape") {
        const json = await callApi("/v2/scrape", {
          url: args.url,
          ...(args.formats != null && { formats: args.formats }),
          ...(args.onlyMainContent != null && { onlyMainContent: args.onlyMainContent }),
        });
        return textResult(json.data?.markdown ?? JSON.stringify(json.data ?? {}));
      }
      throw new Error(`unknown tool: ${name}`);
    } catch (err) {
      return { ...textResult(String(err.message || err)), isError: true };
    }
  },
};

require("readline")
  .createInterface({ input: process.stdin })
  .on("line", async (line) => {
    if (!line.trim()) return;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    if (msg.id === undefined || msg.id === null) return; // notification: no response
    const handler = handlers[msg.method];
    const response = handler
      ? { jsonrpc: "2.0", id: msg.id, result: await handler(msg.params) }
      : {
          jsonrpc: "2.0",
          id: msg.id,
          error: { code: -32601, message: `method not found: ${msg.method}` },
        };
    process.stdout.write(JSON.stringify(response) + "\n");
  });
