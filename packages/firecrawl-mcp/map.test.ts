import assert from "node:assert/strict";
import { test } from "node:test";

import {
  callTool,
  expectToolError,
  expectToolErrors,
  FIRECRAWL,
  jsonResponse,
  mockState,
  toolText,
} from "./test-support.ts";

test("map forwards its options and returns Firecrawl's whole answer", async () => {
  const answer = JSON.stringify({
    id: "map-1",
    links: ["https://nixos.org", "https://nixos.org/manual"],
    success: true,
    warning:
      "Only 2 result(s) found. For broader coverage, try mapping the base domain: nixos.org",
  });
  let captured: unknown;

  mockState.handler = (url, init) => {
    assert.equal(url, `${FIRECRAWL}/v2/map`);
    captured = JSON.parse(String(init?.body));
    return jsonResponse(answer);
  };

  const result = await callTool("map", {
    includeSubdomains: false,
    limit: 10,
    search: "manual",
    url: "https://nixos.org",
  });
  assert.deepEqual(captured, {
    includeSubdomains: false,
    limit: 10,
    search: "manual",
    url: "https://nixos.org",
  });
  assert.equal(toolText(result), answer);
});

test("map rejects out-of-bounds limits and bad types", async () => {
  mockState.handler = () =>
    jsonResponse(JSON.stringify({ links: [], success: true }));
  await expectToolErrors("map", [
    [{ limit: 0 }, /limit/],
    [{ limit: 100_001 }, /limit/],
    [{ limit: 1.5 }, /limit/],
    [{ limit: "50" }, /limit/],
    [{ includeSubdomains: "no" }, /includeSubdomains/],
    [{ search: 7 }, /search/],
    [{ url: "" }, /url/],
  ]);
});

test("map: a response without links is a tool error", async () => {
  mockState.handler = () => jsonResponse(JSON.stringify({ success: true }));
  await expectToolError("map", { url: "https://example.com" }, /no links/);
});
