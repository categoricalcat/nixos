#!/usr/bin/env node
// Minimal MCP stdio server: `search` hits the local SearXNG JSON API with a
// 1:1 param mapping (Firecrawl's searxng adapter drops tbs and pins
// categories via the SEARXNG_CATEGORIES env, so per-request category/date
// filters are impossible through Firecrawl), `scrape` hits the self-hosted
// Firecrawl API.
//
// Replaces the npx firecrawl-mcp package + rename shim: upstream advertises
// tools as firecrawl_search/firecrawl_scrape, which OpenCode then doubles to
// firecrawl_firecrawl_* (small models emit the canonical names and their
// calls fail validation), and its deeply-nested schemas break llama.cpp's
// grammar compiler. Here the tools are natively named search/scrape, so
// OpenCode registers exactly firecrawl_search/firecrawl_scrape, with small
// whitelisted schemas that compile.
//
// Strictest TypeScript, type-checked at build (tsc --noEmit). Zero npm
// dependencies: plain node (>= 22 native type stripping, global fetch),
// newline-delimited JSON-RPC over stdio.

import * as readline from "node:readline";

const API = (
  process.env["FIRECRAWL_API_URL"] || "http://localhost:24002"
).replace(/\/$/, "");
const SEARXNG = (process.env["SEARXNG_URL"] || "").replace(/\/$/, "");

// Shapes read from the Firecrawl API response. Cast after response.json(); a
// null body still throws on property access inside callApi, which callers
// catch.
interface ApiResponse {
  data?: unknown;
  error?: unknown;
  success?: unknown;
}

type JsonRpcId = number | string;

interface RpcError {
  code: number;
  message: string;
}

interface RpcRequest {
  id?: JsonRpcId | null;
  method?: string;
  params?: unknown;
}

type RpcResponse =
  | { error: RpcError; id: JsonRpcId; jsonrpc: "2.0" }
  | { id: JsonRpcId; jsonrpc: "2.0"; result: unknown };

// Shapes read from the SearXNG JSON response. Cast after response.json().
interface SearxResult {
  content?: unknown;
  publishedDate?: unknown;
  title?: unknown;
  url?: unknown;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

// Single source for the time_range schema enum and the search() whitelist.
const TIME_RANGES = new Set(["day", "month", "week", "year"]);

const TOOLS = [
  {
    description:
      "Search the web. Best for finding current information without a known " +
      'page. categories ["news"] = news only, ["science"] = scholarly; ' +
      "time_range = recency; language = locale, e.g. pt-BR.",
    inputSchema: {
      additionalProperties: false,
      properties: {
        categories: {
          description: "Result categories to search.",
          items: {
            enum: [
              "general",
              "news",
              "science",
              "images",
              "videos",
              "it",
              "music",
              "files",
              "social media",
            ],
            type: "string",
          },
          type: "array",
        },
        engines: {
          description:
            "Engine names, not shortcuts: duckduckgo, mojeek, google " +
            "scholar, arxiv, bing news; unknown names are dropped.",
          items: { type: "string" },
          type: "array",
        },
        language: {
          description:
            "BCP-47 locale, e.g. en, pt-BR, de; 'auto' for any language.",
          type: "string",
        },
        pageno: {
          description: "1-indexed result page.",
          minimum: 1,
          type: "number",
        },
        query: { minLength: 1, type: "string" },
        safesearch: {
          description: "0 off, 1 moderate, 2 strict.",
          maximum: 2,
          minimum: 0,
          type: "number",
        },
        time_range: {
          description: "Restrict to results from this period.",
          enum: [...TIME_RANGES],
          type: "string",
        },
        timeout_limit: {
          description: "Max seconds engines may take.",
          type: "number",
        },
      },
      required: ["query"],
      type: "object",
    },
    name: "search",
  },
  {
    description: "Scrape a single URL and return its content as markdown.",
    inputSchema: {
      additionalProperties: false,
      properties: {
        formats: {
          items: {
            enum: ["markdown", "html", "rawHtml", "links", "summary"],
            type: "string",
          },
          type: "array",
        },
        onlyMainContent: { type: "boolean" },
        url: { format: "uri", type: "string" },
      },
      required: ["url"],
      type: "object",
    },
    name: "scrape",
  },
];

interface ToolCall {
  // "arguments" mirrors the JSON-RPC tools/call field name.
  arguments: Record<string, unknown>;
  name: string;
}

async function callApi(path: string, body: unknown): Promise<ApiResponse> {
  const response = await fetch(`${API}${path}`, {
    body: JSON.stringify(body),
    headers: { "Content-Type": "application/json" },
    method: "POST",
    // Slow Playwright scrapes justify 120s; without a bound a hung request
    // hangs the tool call forever.
    signal: AbortSignal.timeout(120_000),
  });
  let json: ApiResponse;
  try {
    json = (await response.json()) as ApiResponse;
  } catch {
    // An empty/invalid body parses as {}; property access stays safe below.
    json = {};
  }
  if (!response.ok || json.success === false) {
    const error = json.error;
    throw new Error(
      typeof error === "string" && error !== ""
        ? error
        : `firecrawl HTTP ${response.status}`,
    );
  }
  return json;
}

// Only fields the agent needs; SearXNG also returns score/engine/category.
function compactResult(result: SearxResult) {
  return {
    ...(typeof result.content === "string" && { content: result.content }),
    ...(typeof result.publishedDate === "string" && {
      publishedDate: result.publishedDate,
    }),
    ...(typeof result.title === "string" && { title: result.title }),
    ...(typeof result.url === "string" && { url: result.url }),
  };
}

function parseToolCall(parameters: unknown): null | ToolCall {
  if (!isRecord(parameters)) return null;
  const name = parameters["name"];
  if (typeof name !== "string") return null;
  const rawArguments = parameters["arguments"];
  return { arguments: isRecord(rawArguments) ? rawArguments : {}, name };
}

async function scrape(arguments_: Record<string, unknown>) {
  const url = arguments_["url"];
  if (typeof url !== "string")
    throw new TypeError("scrape: url must be a string");
  const formats = arguments_["formats"];
  const onlyMainContent = arguments_["onlyMainContent"];
  const json = await callApi("/v2/scrape", {
    url,
    ...(Array.isArray(formats) && { formats }),
    ...(typeof onlyMainContent === "boolean" && { onlyMainContent }),
  });
  const data = json.data;
  const markdown = isRecord(data) ? data["markdown"] : undefined;
  return textResult(
    typeof markdown === "string" ? markdown : JSON.stringify(data ?? {}),
  );
}

const clampInt = (value: number, min: number, max: number) => {
  const truncated = Math.trunc(value);
  return String(Math.min(max, Math.max(min, truncated)));
};

async function search(arguments_: Record<string, unknown>) {
  const query = arguments_["query"];
  if (typeof query !== "string" || query === "") {
    throw new Error("search: query must be a non-empty string");
  }
  if (SEARXNG === "") throw new Error("search: SEARXNG_URL is not configured");
  const categories = arguments_["categories"];
  const engines = arguments_["engines"];
  const language = arguments_["language"];
  const pageno = arguments_["pageno"];
  const safesearch = arguments_["safesearch"];
  const time_range = arguments_["time_range"];
  const timeout_limit = arguments_["timeout_limit"];
  const searchParameters = new URLSearchParams({ format: "json", q: query });
  // llama.cpp grammars enforce types/enums but not minimum/maximum or array
  // length; clamp here so malformed values don't waste a searxng 400.
  if (Array.isArray(categories) && categories.length > 0)
    searchParameters.set("categories", categories.join(","));
  if (Array.isArray(engines) && engines.length > 0)
    searchParameters.set("engines", engines.join(","));
  if (typeof language === "string" && language !== "")
    searchParameters.set("language", language);
  if (typeof pageno === "number")
    searchParameters.set("pageno", clampInt(pageno, 1, Infinity));
  if (typeof safesearch === "number")
    searchParameters.set("safesearch", clampInt(safesearch, 0, 2));
  if (typeof time_range === "string" && TIME_RANGES.has(time_range))
    searchParameters.set("time_range", time_range);
  if (typeof timeout_limit === "number")
    searchParameters.set("timeout_limit", String(Math.max(0, timeout_limit)));
  const response = await fetch(`${SEARXNG}/search?${searchParameters}`, {
    // Tor-routed engines add seconds per request; without a bound a hung
    // fetch hangs the tool call forever (searxng caps engine waits at 25s).
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`searxng HTTP ${response.status}`);
  const json = (await response.json()) as { results?: SearxResult[] };
  const results = Array.isArray(json.results) ? json.results : [];
  return textResult(
    JSON.stringify(results.map((result) => compactResult(result))),
  );
}

function textResult(text: string) {
  return { content: [{ text, type: "text" }] };
}

const handlers: Record<string, (parameters: unknown) => unknown> = {
  initialize: (parameters) => {
    const requested =
      isRecord(parameters) &&
      typeof parameters["protocolVersion"] === "string" &&
      parameters["protocolVersion"] !== ""
        ? parameters["protocolVersion"]
        : "2025-06-18";
    return {
      capabilities: { tools: {} },
      protocolVersion: requested,
      serverInfo: { name: "firecrawl", version: "1.1.1" },
    };
  },

  ping: () => ({}),

  "tools/call": async (parameters) => {
    try {
      const call = parseToolCall(parameters);
      if (call === null) throw new Error("tools/call: missing tool name");
      if (call.name === "search") return await search(call.arguments);
      if (call.name === "scrape") return await scrape(call.arguments);
      throw new Error(`unknown tool: ${call.name}`);
    } catch (error) {
      return {
        ...textResult(error instanceof Error ? error.message : String(error)),
        isError: true,
      };
    }
  },

  "tools/list": () => ({ tools: TOOLS }),
};

async function respond(
  message: RpcRequest,
  id: JsonRpcId,
): Promise<RpcResponse> {
  const handler = handlers[message.method ?? ""];
  if (handler === undefined) {
    return {
      error: { code: -32_601, message: `method not found: ${message.method}` },
      id,
      jsonrpc: "2.0",
    };
  }
  try {
    return { id, jsonrpc: "2.0", result: await handler(message.params) };
  } catch (error) {
    return {
      error: {
        code: -32_603,
        message: error instanceof Error ? error.message : String(error),
      },
      id,
      jsonrpc: "2.0",
    };
  }
}

readline
  .createInterface({ input: process.stdin })
  .on("line", async (line: string) => {
    if (line.trim() === "") return;
    let message: RpcRequest;
    try {
      message = JSON.parse(line) as RpcRequest;
    } catch {
      return;
    }
    const id = message.id;
    if (id === undefined || id === null) return; // notification: no response
    const response = await respond(message, id);
    process.stdout.write(JSON.stringify(response) + "\n");
  });
