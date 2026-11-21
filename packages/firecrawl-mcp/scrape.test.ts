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

test("scrape returns markdown and appends degraded-render warnings", async () => {
  mockState.handler = (url, init) => {
    assert.equal(url, `${FIRECRAWL}/v2/scrape`);
    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    assert.equal(body["url"], "https://example.com");
    return jsonResponse(
      JSON.stringify({
        data: { markdown: "# hi", warning: "fell back to stealthProxy" },
        success: true,
      }),
    );
  };

  const result = await callTool("scrape", { url: "https://example.com" });
  assert.equal(
    toolText(result),
    "# hi\n\n[firecrawl warning] fell back to stealthProxy",
  );
});

test("scrape serializes non-markdown formats as JSON", async () => {
  mockState.handler = () =>
    jsonResponse(
      JSON.stringify({
        data: { links: ["https://a", "https://b"] },
        success: true,
      }),
    );
  const result = await callTool("scrape", {
    formats: ["links"],
    url: "https://example.com",
  });
  assert.equal(
    toolText(result),
    JSON.stringify({ links: ["https://a", "https://b"] }),
  );
});

test("scrape returns the whole document as JSON when formats beyond markdown are requested", async () => {
  const data = { links: ["https://a"], markdown: "# hi" };
  mockState.handler = () =>
    jsonResponse(JSON.stringify({ data, success: true }));
  const result = await callTool("scrape", {
    formats: ["markdown", "links"],
    url: "https://example.com",
  });
  assert.equal(toolText(result), JSON.stringify(data));
});

test("scrape surfaces the render-failure reason instead of an empty result", async () => {
  mockState.handler = () =>
    jsonResponse(
      JSON.stringify({
        data: {
          markdown: "",
          metadata: { error: "playwright unsupported waitFor" },
        },
        success: true,
      }),
    );
  await expectToolError(
    "scrape",
    { url: "https://example.com" },
    /playwright unsupported waitFor/,
  );
});

test("scrape forwards its options and rejects out-of-bounds ones", async () => {
  let captured: unknown;

  mockState.handler = (url, init) => {
    assert.equal(url, `${FIRECRAWL}/v2/scrape`);
    captured = JSON.parse(String(init?.body));
    return jsonResponse(
      JSON.stringify({ data: { markdown: "# ok" }, success: true }),
    );
  };

  await callTool("scrape", {
    excludeTags: ["nav"],
    formats: ["markdown", "rawHtml"],
    includeTags: ["main"],
    onlyMainContent: false,
    timeout: 30_000,
    url: "https://example.com",
    waitFor: 500,
  });
  assert.deepEqual(captured, {
    excludeTags: ["nav"],
    formats: ["markdown", "rawHtml"],
    includeTags: ["main"],
    onlyMainContent: false,
    timeout: 30_000,
    url: "https://example.com",
    waitFor: 500,
  });
  await expectToolErrors("scrape", [
    [{ timeout: 30_000, waitFor: 60_001 }, /waitFor/],
    [{ timeout: 999 }, /timeout/],
    [
      { timeout: 2000, waitFor: 1500 },
      /waitFor must not exceed half of timeout/,
    ],
    [{ formats: [] }, /formats/],
    [{ formats: ["summary"] }, /formats/],
    [{ formats: ["audio"] }, /formats/],
    [{ includeTags: [""] }, /includeTags/],
    [{ onlyMainContent: "yes" }, /onlyMainContent/],
    [{ url: "" }, /url/],
  ]);
});

test("scrape preserves HTTP status when Firecrawl returns a JSON null error body", async () => {
  mockState.handler = () => jsonResponse("null", 502);
  await expectToolError(
    "scrape",
    { url: "https://example.com" },
    /firecrawl HTTP 502/,
  );
});
