import assert from "node:assert/strict";
import { test } from "node:test";
import { isDeepStrictEqual } from "node:util";

import {
  encodePageno,
  encodeSafesearch,
  encodeSearchQuery,
  encodeTimeoutLimit,
  normalizeLanguage,
  parseSearxEnvelopeBody,
  parseSearxngConfig,
  type SearxngListing,
  shouldRetryEnvelope,
  TIME_RANGES,
} from "./searxng-contract.ts";
import {
  fixtureCategories,
  fixtureConfig,
  fixtureEngines,
  searxBody,
} from "./test-support.ts";

const fixtureListing: SearxngListing = {
  categoryNames: new Set(fixtureCategories),
  engineNames: new Set(fixtureEngines),
};

// --- example: contract units --------------------------------------------------

test("timeout_limit accepts 15 and rejects 0, 16, NaN, and infinities", () => {
  assert.equal(encodeTimeoutLimit(15), "15");

  for (const value of [0, -1, 16, 1e21, NaN, Infinity, -Infinity]) {
    assert.throws(
      () => encodeTimeoutLimit(value),
      /timeout_limit/,
      `timeout_limit ${value}`,
    );
  }
});

test("safesearch accepts exactly 0, 1, 2", () => {
  assert.deepEqual(
    [0, 1, 2].map((value) => encodeSafesearch(value)),
    ["0", "1", "2"],
  );

  for (const value of [-1, 3, 1.5, NaN, Infinity]) {
    assert.throws(
      () => encodeSafesearch(value),
      /safesearch/,
      `safesearch ${value}`,
    );
  }
});

test("parseSearxngConfig reads the listing and rejects malformed ones", () => {
  assert.deepEqual(
    parseSearxngConfig(JSON.parse(fixtureConfig)),
    fixtureListing,
  );

  for (const malformed of [
    7,
    null,
    [],
    {},
    { categories: "general" },
    { categories: [7] },
    { categories: [], engines: ["brave"] },
    { categories: [], engines: [{ name: "" }] },
  ]) {
    assert.throws(
      () => parseSearxngConfig(malformed),
      /searxng config/,
      JSON.stringify(malformed),
    );
  }
});

test("envelope guards classify payload and transient failures", () => {
  const pluginOnly = parseSearxEnvelopeBody(
    searxBody({
      answers: [{ answer: "x" }],
      unresponsive_engines: [["brave", "timeout"]],
    }),
  );
  const transient = parseSearxEnvelopeBody(
    searxBody({ unresponsive_engines: [["brave", "timeout"]] }),
  );
  const nonTransient = parseSearxEnvelopeBody(
    searxBody({ unresponsive_engines: [["brave", "HTTP error 500"]] }),
  );
  const withResults = parseSearxEnvelopeBody(searxBody({ results: [{}] }));
  assert.equal(pluginOnly.hasPayload, true);
  assert.equal(shouldRetryEnvelope(pluginOnly), false);
  assert.equal(shouldRetryEnvelope(transient), true);
  assert.equal(shouldRetryEnvelope(nonTransient), false);
  assert.equal(shouldRetryEnvelope(withResults), false);

  for (const malformed of [
    "",
    "nope",
    "[1]",
    "5",
    '{"results": 5}',
    '{"answers": 5}',
  ]) {
    assert.throws(
      () => parseSearxEnvelopeBody(malformed),
      /malformed searxng response/,
      malformed,
    );
  }
});

// Every unresponsive_engines reason the locked SearXNG emits
// (searx/webutils.py exception_classname_to_text), with its retry verdict.
const ENGINE_ERROR_VERDICTS: [string, boolean][] = [
  ["timeout", true],
  ["CAPTCHA", true],
  ["too many requests", true],
  ["access denied", true],
  ["proxy error", true],
  ["HTTP connection error", true],
  ["network error", true],
  ["HTTP protocol error", true],
  ["Suspended: too many requests", true],
  ["HTTP error", false],
  ["parsing error", false],
  ["server API error", false],
  ["SSL error: certificate validation has failed", false],
  ["unexpected crash", false],
];

test("the retry verdict covers every SearXNG engine error text", () => {
  const wrong = ENGINE_ERROR_VERDICTS.filter(
    ([reason, transient]) =>
      shouldRetryEnvelope({
        hasPayload: false,
        unresponsiveEngines: [["brave", reason]],
      }) !== transient,
  );
  assert.deepEqual(wrong, []);
});

// --- seeded properties ------------------------------------------------------

// mulberry32-style dependency-free PRNG (fixed seed below). The accumulator
// keeps growing between calls (Math.trunc, no int32 wrap), but every mixing
// step coerces bitwise, so the sequence stays fully deterministic.
const mulberry32 = (seed: number) => {
  let state = seed;

  return () => {
    state = Math.trunc(state + 0x6d_2b_79_f5);
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
};

const SEED = 0x20_26_11_20;
const CASES = 200;

const assertNoFailures = (failures: string[]) => {
  assert.deepEqual(
    failures,
    [],
    `failing cases (seed ${SEED}, ${CASES} cases): ${JSON.stringify(failures)}`,
  );
};

const LETTERS = "abcdefghijklmnopqrstuvwxyz";

const randomLetter = (random: () => number) =>
  LETTERS[Math.floor(random() * LETTERS.length)] ?? "a";

const randomLocale = (random: () => number): string => {
  let code = randomLetter(random) + randomLetter(random);
  if (random() < 0.5) code += randomLetter(random);

  if (random() < 0.6) {
    const region = random() < 0.5 ? "US" : "br";
    code += (random() < 0.8 ? "-" : "_") + region;
  }

  return code;
};

const randomSubset = (names: string[], random: () => number): string[] => {
  const picked = names.filter(() => random() < 0.5);
  return picked.length > 0
    ? picked
    : [names[Math.floor(random() * names.length)] ?? "general"];
};

test("property: accepted pagenos encode as plain digits; out-of-domain ones always throw", () => {
  const random = mulberry32(SEED);
  const pagenos: number[] = [
    0,
    1,
    2,
    255,
    2 ** 31,
    2 ** 53 - 1,
    2 ** 53,
    1e21,
    NaN,
    Infinity,
    -Infinity,
    0.5,
    -1,
    1.0000000001,
  ];

  for (let index = 0; index < CASES; index += 1) {
    pagenos.push(1 + Math.floor(random() * Number.MAX_SAFE_INTEGER));
  }

  const failures: string[] = [];

  for (const pageno of pagenos) {
    const isInDomain = Number.isSafeInteger(pageno) && pageno >= 1;

    try {
      const encoded = encodePageno(pageno);

      if (!isInDomain)
        failures.push(`accepted out-of-domain pageno: ${pageno}`);
      else if (!/^[1-9]\d*$/.test(encoded) || Number(encoded) !== pageno) {
        failures.push(`bad encoding of ${pageno}: ${encoded}`);
      }
    } catch {
      if (isInDomain) failures.push(`rejected in-domain pageno: ${pageno}`);
    }
  }

  assertNoFailures(failures);
});

const REJECTED = "<rejected>";

const normalizeOrRejected = (value: string) => {
  try {
    return normalizeLanguage(value);
  } catch {
    return REJECTED;
  }
};

test("property: language normalization is exactly the separator map; malformed codes are rejected", () => {
  const random = mulberry32(SEED + 1);
  const accepted = ["auto"];
  for (let index = 0; index < CASES; index += 1)
    accepted.push(randomLocale(random));
  const malformed = [
    "english",
    "zh-Hant",
    "EN",
    "en-",
    "en_US_XX",
    "pt_BR_",
    "1en",
    "en-1S",
    "e",
    "en--US",
    "AUTO",
  ];
  const failures: string[] = [];

  // The canonical form is a fixed point, so idempotence follows.
  for (const value of accepted) {
    const canonical = value.replaceAll("_", "-");
    const once = normalizeOrRejected(value);
    const twice = normalizeOrRejected(once);

    if (once !== canonical || twice !== canonical) {
      failures.push(`${value} -> ${once} -> ${twice}, expected ${canonical}`);
    }
  }

  for (const value of malformed) {
    if (normalizeOrRejected(value) !== REJECTED)
      failures.push(`accepted malformed locale: ${value}`);
  }

  assertNoFailures(failures);
});

// SearXNG's side of the wire (searx/webadapter.py): names split on commas,
// pageno and safesearch through isdigit() + int(), timeout_limit through
// float(), everything else verbatim.
const parseDigits = (raw: string) => (/^\d+$/.test(raw) ? Number(raw) : NaN);
const SEARX_PARSERS: Record<string, (raw: string) => unknown> = {
  categories: (raw) => raw.split(","),
  engines: (raw) => raw.split(","),
  pageno: parseDigits,
  safesearch: parseDigits,
  timeout_limit: Number,
};

test("property: decoding the wire query through SearXNG's parsers recovers every argument", () => {
  const random = mulberry32(SEED + 2);
  const failures: string[] = [];

  for (let index = 0; index < CASES; index += 1) {
    const optional = {
      categories: randomSubset(fixtureCategories, random),
      engines: randomSubset(fixtureEngines, random),
      language: randomLocale(random),
      pageno: 1 + Math.floor(random() * Number.MAX_SAFE_INTEGER),
      safesearch: Math.floor(random() * 3),
      time_range:
        TIME_RANGES[Math.floor(random() * TIME_RANGES.length)] ?? "day",
      timeout_limit: 0.1 + random() * 14.9,
    };
    // Each optional argument is present with probability 1/2.
    const arguments_: Record<string, unknown> = {
      ...Object.fromEntries(
        Object.entries(optional).filter(() => random() < 0.5),
      ),
      query: `round trip #${index} & symbols=✓ +%20`,
    };
    const { language, query, ...rest } = arguments_;
    const expected = {
      ...rest,
      format: "json",
      q: query,
      ...(typeof language === "string" && {
        language: language.replaceAll("_", "-"),
      }),
    };
    let wire: string;

    try {
      wire = encodeSearchQuery(arguments_, fixtureListing).toString();
    } catch (error) {
      failures.push(
        `rejected ${JSON.stringify(arguments_)} (${String(error)})`,
      );
      continue;
    }

    const pairs = [...new URLSearchParams(wire)];
    const decoded = Object.fromEntries(
      pairs.map(([key, raw]) => [key, SEARX_PARSERS[key]?.(raw) ?? raw]),
    );

    if (
      pairs.length !== Object.keys(decoded).length ||
      !isDeepStrictEqual(decoded, expected)
    ) {
      failures.push(
        `${JSON.stringify(arguments_)} decoded as ${JSON.stringify(decoded)}`,
      );
    }
  }

  assertNoFailures(failures);
});

test("property: categories and engines are both present when supplied", () => {
  const random = mulberry32(SEED + 3);
  const failures: string[] = [];

  for (let index = 0; index < CASES; index += 1) {
    const categories = randomSubset(fixtureCategories, random);
    const engines = randomSubset(fixtureEngines, random);
    const parameters = encodeSearchQuery(
      { categories, engines, query: "q" },
      fixtureListing,
    );

    if (parameters.get("categories") !== categories.join(",")) {
      failures.push(`categories not encoded: ${categories.join(",")}`);
    }

    if (parameters.get("engines") !== engines.join(",")) {
      failures.push(`engines not encoded: ${engines.join(",")}`);
    }
  }

  assertNoFailures(failures);
});

test("property: out-of-domain values always throw, naming the parameter", () => {
  const random = mulberry32(SEED + 4);

  // "zz"+letter+digit never collides with the fixture names.
  const junkNames = (kind: "categories" | "engines"): [string, unknown][] => {
    const cases: [string, unknown][] = [];

    for (let index = 0; index < CASES; index += 1) {
      let name = "zz" + randomLetter(random) + Math.floor(random() * 10);
      if (kind === "engines") name += " news";
      cases.push([kind, [name]]);
    }

    return cases;
  };

  const cases: [string, unknown][] = [
    ...["", " ", "  ", "bogus", "general,", ",general"].map(
      (name) => ["categories", [name]] as [string, unknown],
    ),
    ["categories", "science"],
    ["engines", 5],
    ["engines", ["not-an-engine"]],
    ...junkNames("categories"),
    ...junkNames("engines"),
  ];

  for (const value of [0, -1, 2 ** 53, 1e21, NaN, Infinity, 1.5]) {
    cases.push(["pageno", value]);
  }

  for (const value of [-1, 3, 1.5, NaN, Infinity]) {
    cases.push(["safesearch", value]);
  }

  for (const value of [0, -1, 15.5, 1e21, NaN, Infinity]) {
    cases.push(["timeout_limit", value]);
  }

  for (const value of ["decade", "", " week", "week "]) {
    cases.push(["time_range", value]);
  }

  for (const value of ["english", "zh-Hant", "en-", "AUTO"]) {
    cases.push(["language", value]);
  }

  const failures: string[] = [];

  for (const [parameter, value] of cases) {
    try {
      encodeSearchQuery({ [parameter]: value, query: "q" }, fixtureListing);
      failures.push(
        `accepted out-of-domain ${parameter}: ${JSON.stringify(value)}`,
      );
    } catch (error) {
      if (!String(error).includes(parameter)) {
        failures.push(
          `rejected ${parameter} for another reason: ${String(error)}`,
        );
      }
    }
  }

  assertNoFailures(failures);
});
