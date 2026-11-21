import assert from "node:assert/strict";
import { test } from "node:test";

import { isRecord } from "./guards.ts";
import {
  expectToolError,
  fixtureCategories,
  fixtureConfig,
  handleLine,
  jsonResponse,
  listTools,
  mockState,
  request,
  SEARXNG,
} from "./test-support.ts";

const schemaProperties = (schema: unknown) => {
  assert.ok(isRecord(schema));
  const properties = schema["properties"];
  assert.ok(isRecord(properties));
  return properties;
};

const searchCategoryItems = (
  tools: { inputSchema: unknown; name: string }[],
) => {
  const categories = schemaProperties(
    tools.find((tool) => tool.name === "search")?.inputSchema,
  )["categories"];
  assert.ok(isRecord(categories));
  const items = categories["items"];
  assert.ok(isRecord(items));
  return items;
};

// --- example: tools/list ----------------------------------------------------

// These two run first and in this order: the server keeps the first
// successful /config listing for the life of the process, and every later
// test in this file shares that fixture listing.
test("tools/list leaves category items unconstrained when /config is unavailable", async () => {
  mockState.handler = (url) => {
    assert.equal(url, `${SEARXNG}/config`);
    return jsonResponse("{}", 500);
  };

  const tools = await listTools();
  assert.deepEqual(
    tools.map((tool) => tool.name).toSorted((a, b) => a.localeCompare(b)),
    ["map", "scrape", "search"],
  );
  assert.equal(searchCategoryItems(tools)["enum"], undefined);
});

test("tools/call rejects unlisted search arguments without fetching /config", async () => {
  mockState.handler = () => {
    throw new Error("unexpected fetch");
  };

  await expectToolError(
    "search",
    { query: "q", timeRange: "day" },
    /unknown arguments: timeRange/,
  );
});

test("tools/list fills the categories enum from the instance /config listing", async () => {
  mockState.handler = (url) => {
    assert.equal(url, `${SEARXNG}/config`);
    return jsonResponse(fixtureConfig);
  };

  assert.deepEqual(
    searchCategoryItems(await listTools())["enum"],
    fixtureCategories,
  );
});

// --- example: schemas ---------------------------------------------------------

const FORBIDDEN_COMBINATORS = new Set([
  "$ref",
  "allOf",
  "anyOf",
  "not",
  "oneOf",
]);
const SCALAR_TYPES = new Set([
  "boolean",
  "integer",
  "null",
  "number",
  "string",
]);

const flatSchemaIssues = (schema: unknown, path: string): string[] => {
  if (!isRecord(schema)) return [`${path}: not an object`];
  const issues: string[] = [];

  for (const [key, value] of Object.entries(schema)) {
    if (FORBIDDEN_COMBINATORS.has(key))
      issues.push(`${path}: ${key} combinator`);

    if (isRecord(value))
      issues.push(...flatSchemaIssues(value, `${path}.${key}`));
    else if (Array.isArray(value)) {
      for (const [index, entry] of value.entries()) {
        if (isRecord(entry))
          issues.push(...flatSchemaIssues(entry, `${path}.${key}[${index}]`));
      }
    }
  }

  const properties = schema["properties"];
  if (!isRecord(properties)) return issues;

  for (const [name, property] of Object.entries(properties)) {
    if (!isRecord(property)) {
      issues.push(`${path}.${name}: property not an object`);
      continue;
    }

    const type = property["type"];

    if (type === "array") {
      const items = property["items"];

      if (!isRecord(items) || !SCALAR_TYPES.has(String(items["type"]))) {
        issues.push(`${path}.${name}: array items not scalar`);
      }
    } else if (!SCALAR_TYPES.has(String(type))) {
      issues.push(`${path}.${name}: not a scalar or scalar-array`);
    }
  }

  return issues;
};

test("shipped schemas are flat: every property is a scalar or an array of scalars", async () => {
  const tools = await listTools();
  const issues = tools.flatMap((tool) =>
    flatSchemaIssues(tool.inputSchema, tool.name),
  );
  assert.deepEqual(issues, [], `flat-schema violations:\n${issues.join("\n")}`);
});

test("every integer-typed schema property is rejected at runtime when fractional", async () => {
  mockState.handler = () => {
    throw new Error("unexpected fetch");
  };

  const required: Record<string, Record<string, unknown>> = {
    map: { url: "https://example.com" },
    scrape: { url: "https://example.com" },
    search: { query: "q" },
  };
  const integral: string[] = [];
  const tools = await listTools();

  for (const tool of tools) {
    const properties = Object.entries(schemaProperties(tool.inputSchema));

    for (const [name, property] of properties) {
      if (!isRecord(property) || property["type"] !== "integer") continue;
      integral.push(`${tool.name}.${name}`);
      await expectToolError(
        tool.name,
        { ...required[tool.name], [name]: 1.5 },
        new RegExp(name),
      );
    }
  }

  assert.deepEqual(
    integral.toSorted((a, b) => a.localeCompare(b)),
    ["map.limit", "scrape.timeout", "scrape.waitFor", "search.pageno"],
  );
});

// --- example: RPC dispatch ------------------------------------------------------

test("initialize echoes the requested protocolVersion", async () => {
  const response = await request("initialize", {
    protocolVersion: "2025-06-18",
  });
  assert.ok("result" in response, JSON.stringify(response));
  const result = response.result as { protocolVersion: string };
  assert.equal(result.protocolVersion, "2025-06-18");
});

test("Object.prototype names are neither tools nor methods", async () => {
  for (const name of ["constructor", "toString", "__proto__"]) {
    await expectToolError(name, {}, /unknown tool/);
    const response = await request(name, undefined);
    assert.ok(
      "error" in response && response.error.code === -32_601,
      `${name}: ${JSON.stringify(response)}`,
    );
  }
});

test("arguments the schema does not list are rejected, naming them", async () => {
  mockState.handler = () => {
    throw new Error("unexpected fetch");
  };

  const cases: [string, string, string][] = [
    ["search", '{"query":"q","timeRange":"day"}', "timeRange"],
    ["search", '{"query":"q","format":"html"}', "format"],
    ["scrape", '{"url":"https://example.com","__proto__":1}', "__proto__"],
    ["map", '{"url":"https://example.com","constructor":5}', "constructor"],
  ];

  for (const [name, json, unknownKey] of cases) {
    await expectToolError(
      name,
      JSON.parse(json),
      new RegExp(`unknown arguments: ${unknownKey}`),
    );
  }
});

test("tools/call rejects non-object arguments", async () => {
  mockState.handler = () => {
    throw new Error("unexpected fetch");
  };

  for (const bad of ["foo", 123, null, [], ["a"]]) {
    await expectToolError("search", bad, /arguments must be an object/);
  }
});

test("stdio framing ignores null, non-objects, notifications, and bad ids without crashing", async () => {
  for (const line of [
    "",
    " \t",
    "{not json",
    "null",
    "[]",
    "42",
    '"x"',
    '{"method":"notifications/initialized"}',
    '{"id":null,"method":"ping"}',
    '{"id":true,"method":"ping"}',
    '{"id":{},"method":"ping"}',
  ]) {
    assert.equal(await handleLine(line), null, line);
  }

  const ping = await handleLine('{"id":1,"method":"ping"}');
  assert.deepEqual(JSON.parse(ping ?? ""), {
    id: 1,
    jsonrpc: "2.0",
    result: {},
  });

  const nonStringMethod = await handleLine('{"id":2,"method":["ping"]}');
  const parsed = JSON.parse(nonStringMethod ?? "") as {
    error?: { code: number };
    id: number;
  };
  assert.equal(parsed.id, 2);
  assert.equal(parsed.error?.code, -32_601);
});
