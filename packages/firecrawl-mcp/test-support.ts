// Shared node:test support for the firecrawl-mcp suite: endpoint setup, the
// mocked fetch transport, RPC helpers, and the fixture instance listing.
//
// Evidence label: the package is type-checked (tsc --noEmit at build),
// example-tested and seeded-property-tested by the *.test.ts files (node
// --test at check). This is NOT formal verification, and the structural
// flat-schema test is NOT an actual llama.cpp grammar compile — only the
// live OpenCode/llama.cpp registration smoke test may claim grammar-compiler
// compatibility.

import assert from "node:assert/strict";
import { after, before } from "node:test";

export const FIRECRAWL = "http://firecrawl.test";
export const SEARXNG = "http://searxng.test";

// The tool modules read their endpoints at import time, so the mocked
// origins are set before the server's dynamic import. Test files reach the
// server only through this module and never import a tool module
// statically.
process.env["FIRECRAWL_API_URL"] = FIRECRAWL;
process.env["SEARXNG_URL"] = SEARXNG;
const { handleLine, respond } = await import("./firecrawl-mcp.ts");
export { handleLine };

// --- mock HTTP ------------------------------------------------------------

type MockHandler = (
  url: string,
  init?: RequestInit,
) => Promise<Response> | Response;

// The mock transport is installed over the global for the whole file via
// Object.defineProperty (configurable, writable): plain `globalThis.fetch =
// …` assignment is what the lint rules reserve for production code, and the
// defineProperty form restores the real transport just as cleanly.
export const mockState: {
  fetchCount: number;
  handler: MockHandler;
} = {
  fetchCount: 0,
  handler: () => {
    throw new Error("unexpected fetch");
  },
};
const realFetch = globalThis.fetch;

const mockFetch: typeof fetch = async (input, init) => {
  mockState.fetchCount += 1;
  return await mockState.handler(String(input), init);
};

const installFetch = (transport: typeof fetch) =>
  Object.defineProperty(globalThis, "fetch", {
    configurable: true,
    value: transport,
    writable: true,
  });

before(() => {
  installFetch(mockFetch);
});
after(() => {
  installFetch(realFetch);
});

export const jsonResponse = (body: string, status = 200) =>
  new Response(body, { status });

export const searxBody = (overrides: Record<string, unknown>) =>
  JSON.stringify({
    answers: [],
    corrections: [],
    infoboxes: [],
    query: "q",
    results: [],
    suggestions: [],
    unresponsive_engines: [],
    ...overrides,
  });

// --- fixture instance listing ---------------------------------------------

export const fixtureCategories = [
  "general",
  "it",
  "news",
  "packages",
  "q&a",
  "repos",
  "science",
];
export const fixtureEngines = [
  "arxiv",
  "brave",
  "brave.news",
  "duckduckgo",
  "duckduckgo news",
  "google scholar",
  "wikinews",
];
export const fixtureConfig = JSON.stringify({
  categories: fixtureCategories,
  engines: fixtureEngines.map((name) => ({ name })),
});

// --- RPC helpers ------------------------------------------------------------

interface RpcResult {
  content: { text: string; type: string }[];
  isError?: boolean;
}

interface ShippedTool {
  description: string;
  inputSchema: unknown;
  name: string;
}

export const request = (method: string, parameters: unknown) =>
  respond({ id: 1, method, params: parameters }, 1);

export const listTools = async (): Promise<ShippedTool[]> => {
  const response = await request("tools/list", undefined);
  assert.ok("result" in response, JSON.stringify(response));
  return (response.result as { tools: ShippedTool[] }).tools;
};

export const callTool = async (name: string, toolArguments: unknown) => {
  const response = await request("tools/call", {
    arguments: toolArguments,
    name,
  });
  assert.ok("result" in response, JSON.stringify(response));
  return response.result as RpcResult;
};

export const toolText = (result: RpcResult) => result.content[0]?.text ?? "";

export const expectToolError = async (
  name: string,
  toolArguments: unknown,
  match: RegExp,
) => {
  const result = await callTool(name, toolArguments);
  assert.equal(result.isError, true, JSON.stringify(result));
  assert.match(toolText(result), match, JSON.stringify(result));
};

// Each case overrides a valid base call ({ url: "https://example.com" }).
export const expectToolErrors = async (
  name: string,
  cases: [Record<string, unknown>, RegExp][],
) => {
  for (const [overrides, match] of cases) {
    await expectToolError(
      name,
      { url: "https://example.com", ...overrides },
      match,
    );
  }
};
