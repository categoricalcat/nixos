import assert from "node:assert/strict";
import { before, test } from "node:test";

import {
  callTool,
  expectToolError,
  fixtureConfig,
  jsonResponse,
  listTools,
  mockState,
  searxBody,
  SEARXNG,
  toolText,
} from "./test-support.ts";

// The server keeps the first successful /config listing for the life of the
// process; priming it with the fixture makes every name check below run
// against that listing.
before(async () => {
  mockState.handler = (url) => {
    assert.equal(url, `${SEARXNG}/config`);
    return jsonResponse(fixtureConfig);
  };

  await listTools();
});

const resetFetchCount = () => {
  mockState.fetchCount = 0;
};

test("search returns plugin-only answers verbatim without a retry (answers count as payload)", async () => {
  const body = searxBody({
    answers: [
      {
        answer: "e0a09bf9c0d3af5a",
        name: "Hash plugin",
        url: "https://md5.example",
      },
    ],
    unresponsive_engines: [["brave", "timeout"]],
  });

  mockState.handler = (url) => {
    assert.ok(url.startsWith(`${SEARXNG}/search?`), url);
    return jsonResponse(body);
  };

  resetFetchCount();
  const result = await callTool("search", { query: "md5 hello" });
  assert.equal(mockState.fetchCount, 1);
  assert.equal(toolText(result), body);
});

test("search returns valid zero results verbatim without a retry", async () => {
  const body = searxBody({});
  mockState.handler = () => jsonResponse(body);
  resetFetchCount();
  const result = await callTool("search", { query: "no results anywhere" });
  assert.equal(mockState.fetchCount, 1);
  assert.equal(toolText(result), body);
});

test("search retries once when every engine failed transiently", async () => {
  const failing = searxBody({
    unresponsive_engines: [
      ["brave", "timeout"],
      ["duckduckgo", "too many requests"],
    ],
  });
  const recovered = searxBody({ results: [{ title: "t", url: "https://x" }] });
  let calls = 0;

  mockState.handler = () => {
    calls += 1;
    return jsonResponse(calls === 1 ? failing : recovered);
  };

  const result = await callTool("search", { query: "q" });
  assert.equal(calls, 2);
  assert.equal(toolText(result), recovered);
});

test("search does not retry non-transient failures and returns the body as it is", async () => {
  const body = searxBody({
    unresponsive_engines: [["brave", "HTTP error 500"]],
  });
  mockState.handler = () => jsonResponse(body);
  resetFetchCount();
  const result = await callTool("search", { query: "q" });
  assert.equal(mockState.fetchCount, 1);
  assert.equal(toolText(result), body);
});

test("search returns partial unresponsive_engines with results as they are", async () => {
  const body = searxBody({
    results: [{ title: "t", url: "https://x" }],
    unresponsive_engines: [["brave", "timeout"]],
  });
  mockState.handler = () => jsonResponse(body);
  resetFetchCount();
  const result = await callTool("search", { query: "q" });
  assert.equal(mockState.fetchCount, 1);
  assert.equal(toolText(result), body);
});

test("search: malformed JSON and HTTP errors are tool errors", async () => {
  mockState.handler = () => jsonResponse("{not json");
  await expectToolError("search", { query: "q" }, /malformed searxng response/);
  mockState.handler = () => jsonResponse("bad gateway", 502);
  await expectToolError("search", { query: "q" }, /searxng HTTP 502/);
});

test("search rejects what the instance would refuse, drop, or cap", async () => {
  mockState.handler = () => jsonResponse(searxBody({}));
  const rejections: [string, unknown][] = [
    ["categories", ["bogus"]],
    ["categories", [""]],
    ["categories", [" "]],
    ["categories", "science"],
    ["engines", ["bogus"]],
    ["engines", [" brave"]],
    ["engines", [7]],
    ["language", "english"],
    ["language", "zh-Hant"],
    ["pageno", 0],
    ["pageno", 2 ** 53],
    ["pageno", 1e21],
    ["pageno", 1.5],
    ["pageno", "2"],
    ["safesearch", 3],
    ["safesearch", 1.5],
    ["time_range", "decade"],
    ["time_range", "month "],
    ["timeout_limit", 0],
    ["timeout_limit", 15.5],
  ];

  for (const [parameter, value] of rejections) {
    await expectToolError(
      "search",
      { [parameter]: value, query: "q" },
      new RegExp(parameter),
    );
  }

  await expectToolError("search", { query: "" }, /query/);
  await expectToolError("search", { query: 7 }, /query/);
});

test("search encodes every parameter 1:1 and unions categories with engines", async () => {
  let captured = "";

  mockState.handler = (url) => {
    assert.ok(url.startsWith(`${SEARXNG}/search?`), url);
    captured = url.slice(`${SEARXNG}/search?`.length);
    return jsonResponse(searxBody({}));
  };

  await callTool("search", {
    categories: ["it", "science"],
    engines: ["arxiv", "brave"],
    language: "pt_BR",
    pageno: 2,
    query: "nixos flake",
    safesearch: 1,
    time_range: "month",
    timeout_limit: 7.5,
  });
  const parameters = new URLSearchParams(captured);
  assert.equal(parameters.get("format"), "json");
  assert.equal(parameters.get("q"), "nixos flake");
  assert.equal(parameters.get("categories"), "it,science");
  assert.equal(parameters.get("engines"), "arxiv,brave");
  assert.equal(parameters.get("language"), "pt-BR");
  assert.equal(parameters.get("pageno"), "2");
  assert.equal(parameters.get("safesearch"), "1");
  assert.equal(parameters.get("time_range"), "month");
  assert.equal(parameters.get("timeout_limit"), "7.5");
});
