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
// Strictest TypeScript, type-checked at build (tsc --noEmit). Zero npm
// dependencies: plain node (>= 22 native type stripping, global fetch),
// newline-delimited JSON-RPC over stdio.

import * as readline from "node:readline";

const API = (
  process.env["FIRECRAWL_API_URL"] || "http://localhost:24002"
).replace(/\/$/, "");

// Shapes read from the Firecrawl API response. Cast after response.json(); a null
// body still throws on property access inside callApi, which callers catch.
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

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const TOOLS = [
  {
    description:
      "Search the web. Best for finding current information when you don't know the exact page.",
    inputSchema: {
      additionalProperties: false,
      properties: {
        limit: { type: "number" },
        query: { minLength: 1, type: "string" },
        sources: {
          items: {
            additionalProperties: false,
            properties: {
              type: { enum: ["web", "images", "news"], type: "string" },
            },
            required: ["type"],
            type: "object",
          },
          type: "array",
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

async function search(arguments_: Record<string, unknown>) {
  const query = arguments_["query"];
  if (typeof query !== "string" || query === "") {
    throw new Error("search: query must be a non-empty string");
  }
  const limit = arguments_["limit"];
  const sources = arguments_["sources"];
  const json = await callApi("/v2/search", {
    query,
    ...(typeof limit === "number" && { limit }),
    ...(Array.isArray(sources) && { sources }),
  });
  // With explicit sources, data may hold images/news alongside web.
  const data = json.data;
  if (Array.isArray(sources)) return textResult(JSON.stringify(data ?? {}));
  const web = isRecord(data) ? data["web"] : undefined;
  return textResult(JSON.stringify(web ?? data ?? []));
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
      serverInfo: { name: "firecrawl", version: "1.0.0" },
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
