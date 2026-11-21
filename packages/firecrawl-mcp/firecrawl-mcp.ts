// Entry module for the firecrawl-mcp wrapper (node <this file>) and an
// importable module for the node:test suite: newline-delimited JSON-RPC
// over stdio, dispatching MCP tool calls to one module per tool — search.ts
// (local SearXNG), scrape.ts and map.ts (self-hosted Firecrawl API).
//
// Replaces the npx firecrawl-mcp package + rename shim: upstream advertises
// tools as firecrawl_search/firecrawl_scrape, which OpenCode then doubles to
// firecrawl_firecrawl_* (small models emit the canonical names and their
// calls fail validation), and its deeply-nested schemas break llama.cpp's
// grammar compiler. Here the tools are natively named search/scrape/map, so
// OpenCode registers exactly firecrawl_search/firecrawl_scrape/
// firecrawl_map, with small flat schemas that compile.
//
// Strictest TypeScript, type-checked at build (tsc --noEmit) and tested at
// check (node --test, examples + seeded properties). Zero npm dependencies:
// plain node (>= 24 native type stripping, global fetch).

import * as readline from "node:readline";

import { isNonEmptyString, isRecord } from "./guards.ts";
import { map, mapDefinition } from "./map.ts";
import { scrape, scrapeDefinition } from "./scrape.ts";
import { instanceListing, search, searchDefinition } from "./search.ts";

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

interface ToolCall {
  // "arguments" mirrors the JSON-RPC tools/call field name.
  arguments: Record<string, unknown>;
  name: string;
}

// Own keys only: a plain index also resolves Object.prototype members
// ("constructor", "toString", "__proto__") as tools or methods.
const ownEntry = <T>(table: Record<string, T>, key: string): T | undefined =>
  Object.hasOwn(table, key) ? table[key] : undefined;

// One registry serves tools/list and tools/call; only the search definition
// depends on the instance (its categories enum). Accepted argument names are
// static, so tools/call validates them without triggering a /config fetch.
const tools = {
  map: {
    accepted: Object.keys(mapDefinition.inputSchema.properties),
    call: map,
    definition: () => mapDefinition,
  },
  scrape: {
    accepted: Object.keys(scrapeDefinition.inputSchema.properties),
    call: scrape,
    definition: () => scrapeDefinition,
  },
  search: {
    accepted: Object.keys(searchDefinition(null).inputSchema.properties),
    call: search,
    definition: async () => searchDefinition(await instanceListing()),
  },
};

function parseToolCall(parameters: unknown): null | ToolCall {
  if (!isRecord(parameters)) return null;
  const name = parameters["name"];
  if (typeof name !== "string") return null;
  const rawArguments = parameters["arguments"];
  if (rawArguments === undefined) return { arguments: {}, name };

  if (!isRecord(rawArguments)) {
    throw new TypeError("tools/call: arguments must be an object");
  }

  return { arguments: rawArguments, name };
}

function textResult(text: string) {
  return { content: [{ text, type: "text" }] };
}

const handlers: Record<string, (parameters: unknown) => unknown> = {
  initialize: (parameters) => {
    const requested =
      isRecord(parameters) && isNonEmptyString(parameters["protocolVersion"])
        ? parameters["protocolVersion"]
        : "2025-06-18";
    return {
      capabilities: { tools: {} },
      protocolVersion: requested,
      serverInfo: { name: "firecrawl", version: "1.2.0" },
    };
  },

  ping: () => ({}),

  "tools/call": async (parameters) => {
    try {
      const call = parseToolCall(parameters);
      if (call === null) throw new Error("tools/call: missing tool name");
      const tool = ownEntry(tools, call.name);
      if (tool === undefined) throw new Error(`unknown tool: ${call.name}`);
      // The schema is the whole argument contract: a name it does not list
      // (a typo like timeRange) is rejected instead of silently ignored.
      const unlisted = Object.keys(call.arguments).filter(
        (key) => !tool.accepted.includes(key),
      );

      if (unlisted.length > 0) {
        throw new Error(
          `${call.name}: unknown arguments: ${unlisted.join(", ")} ` +
            `(accepted: ${tool.accepted.join(", ")})`,
        );
      }

      return textResult(await tool.call(call.arguments));
    } catch (error) {
      return {
        ...textResult(error instanceof Error ? error.message : String(error)),
        isError: true,
      };
    }
  },

  "tools/list": async () => ({
    tools: await Promise.all(
      Object.entries(tools).map(async ([name, tool]) => ({
        ...(await tool.definition()),
        name,
      })),
    ),
  }),
};

export async function handleLine(line: string): Promise<null | string> {
  if (line.trim() === "") return null;
  let parsed: unknown;

  try {
    parsed = JSON.parse(line);
  } catch {
    return null;
  }

  if (!isRecord(parsed)) return null;
  const id = parsed["id"];
  if (typeof id !== "string" && typeof id !== "number") return null;
  const method = parsed["method"];
  const request: RpcRequest = {
    id,
    ...(typeof method === "string" && { method }),
    ...(Object.hasOwn(parsed, "params") && { params: parsed["params"] }),
  };
  return JSON.stringify(await respond(request, id));
}

export async function respond(
  message: RpcRequest,
  id: JsonRpcId,
): Promise<RpcResponse> {
  const handler =
    typeof message.method === "string"
      ? ownEntry(handlers, message.method)
      : undefined;

  if (handler === undefined) {
    return {
      error: {
        code: -32_601,
        message: `method not found: ${String(message.method)}`,
      },
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

// Only the real entry point runs the stdio loop; importing this module (the
// node:test suite) must stay side-effect-free. import.meta.main stays true
// through symlinked entries, unlike comparing import.meta.url with
// pathToFileURL(process.argv[1]).
if (import.meta.main) {
  readline
    .createInterface({ input: process.stdin })
    .on("line", async (line: string) => {
      const reply = await handleLine(line);
      if (reply !== null) process.stdout.write(`${reply}\n`);
    });
}
