// Pure SearXNG Search-API contract for firecrawl-mcp: parameter types,
// normalizers, query encoding, envelope guards, and transient-failure
// classification. No I/O lives here — search.ts keeps the fetches, and this
// file is imported by it and by the node:test suite.
//
// The contract mirrors the locked SearXNG source (searx/webadapter.py,
// searx/webutils.py): its documented Search API has eight parameters (q,
// categories, language, pageno, time_range, format, safesearch, theme) and
// the query parser additionally reads `engines` and `timeout_limit`.
// `format` is pinned to json (this is a JSON client) and `theme` only
// shapes HTML, so the tool exposes the other eight. Each tool parameter
// maps to exactly one SearXNG parameter and keeps SearXNG's meaning; the
// tool accepts what the instance accepts and rejects what the instance
// would refuse, drop silently, cap silently, or run with no time budget.

import { isNonEmptyString, isRecord } from "./guards.ts";

const isStringArray = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((entry) => typeof entry === "string");

// searx/webutils.py VALID_LANGUAGE_CODE. "auto" is accepted alongside it.
const LANGUAGE_CODE = /^[a-z]{2,3}(-[a-zA-Z]{2})?$/;

// Single source for the time_range schema enum and validation; the parser
// accepts exactly these four (parse_time_range).
export const TIME_RANGES = ["day", "month", "week", "year"] as const;

// SearXNG parses pageno with isdigit() and rejects exponent notation with
// HTTP 400, so only safe integers >= 1 rendered as plain digits go out.
export function encodePageno(value: unknown): string {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new TypeError(
      `search: pageno must be a safe integer >= 1, got: ${String(value)}`,
    );
  }

  return String(value);
}

export function encodeSafesearch(value: unknown): string {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0 ||
    value > 2
  ) {
    throw new TypeError(
      `search: safesearch must be 0, 1, or 2, got: ${String(value)}`,
    );
  }

  return String(value);
}

export function encodeTimeRange(value: unknown): string {
  if (
    typeof value !== "string" ||
    !(TIME_RANGES as readonly string[]).includes(value)
  ) {
    throw new TypeError(
      `search: time_range must be one of: ${TIME_RANGES.join(", ")}`,
    );
  }

  return value;
}

// SearXNG accepts any float for timeout_limit and silently caps it at
// outgoing.max_request_timeout (15.0, modules/services/searxng.nix), while
// 0 times every engine out. Reject outside (0, 15] so nothing runs with no
// time budget or a silently different one. Exported: the tool schema's
// maximum derives from the same constant.
export const MAX_TIMEOUT_LIMIT = 15;

// The fields the retry policy depends on; everything else in the envelope
// passes through to the caller verbatim.
export interface SearxEnvelope {
  hasPayload: boolean;
  unresponsiveEngines: [string, string][];
}

// Category and engine names this instance accepts, from its own /config
// listing; null when the listing is unavailable (then names cannot be
// checked and run unconstrained).
export interface SearxngListing {
  categoryNames: Set<string>;
  engineNames: Set<string>;
}

// Whole tool-arguments -> SearXNG query encoding; throws on anything the
// instance would refuse, drop, or cap. An empty name array encodes no
// parameter (SearXNG then applies its defaults), matching the instance's
// own treatment of an empty list.
export function encodeSearchQuery(
  arguments_: Record<string, unknown>,
  listing: null | SearxngListing,
): URLSearchParams {
  const query = arguments_["query"];

  if (!isNonEmptyString(query)) {
    throw new Error("search: query must be a non-empty string");
  }

  const parameters = new URLSearchParams({ format: "json", q: query });
  encodeNames("categories", arguments_["categories"], listing, parameters);
  encodeNames("engines", arguments_["engines"], listing, parameters);

  // Explicit time_range is never silently removed, not even for news-only
  // queries: explicit means explicit.
  const scalarEncoders: [string, (value: unknown) => string][] = [
    ["language", normalizeLanguage],
    ["pageno", encodePageno],
    ["safesearch", encodeSafesearch],
    ["time_range", encodeTimeRange],
    ["timeout_limit", encodeTimeoutLimit],
  ];

  for (const [key, encode] of scalarEncoders) {
    const value = arguments_[key];

    if (value !== undefined) parameters.set(key, encode(value));
  }

  return parameters;
}

export function encodeTimeoutLimit(value: unknown): string {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value <= 0 ||
    value > MAX_TIMEOUT_LIMIT
  ) {
    throw new TypeError(
      `search: timeout_limit must be a finite number in (0, ${MAX_TIMEOUT_LIMIT}], got: ${String(value)}`,
    );
  }

  return String(value);
}

// The one normalization is the locale separator (pt_BR -> pt-BR); every
// other shape is accepted verbatim or rejected, never clamped.
export function normalizeLanguage(value: unknown): string {
  if (value === "auto") return value;
  const code = typeof value === "string" ? value.replaceAll("_", "-") : "";

  if (!LANGUAGE_CODE.test(code)) {
    throw new TypeError(
      `search: language must be "auto" or match ^[a-z]{2,3}(-[a-zA-Z]{2})?$, got: ${String(value)}`,
    );
  }

  return code;
}

// Minimal shape validation on a parsed copy of the response body: the body
// itself is returned to the agent verbatim, so validation covers only
// results/answers/infoboxes/unresponsive_engines.
export function parseSearxEnvelopeBody(body: string): SearxEnvelope {
  let json: unknown;

  try {
    json = JSON.parse(body);
  } catch {
    throw new Error("search: malformed searxng response (invalid JSON)");
  }

  if (!isRecord(json)) {
    throw new Error("search: malformed searxng response (not an object)");
  }

  const results = arrayField(json, "results");
  const answers = arrayField(json, "answers");
  const infoboxes = arrayField(json, "infoboxes");
  const unresponsiveRaw = arrayField(json, "unresponsive_engines");
  return {
    // Plugin-only answers and infoboxes count as payload.
    hasPayload:
      results.length > 0 || answers.length > 0 || infoboxes.length > 0,
    unresponsiveEngines: unresponsiveRaw.filter(
      (entry): entry is [string, string] =>
        Array.isArray(entry) &&
        isNonEmptyString(entry[0]) &&
        isNonEmptyString(entry[1]),
    ),
  };
}

function arrayField(json: Record<string, unknown>, key: string): unknown[] {
  const value = json[key];
  if (value === undefined) return [];

  if (!Array.isArray(value)) {
    throw new TypeError(
      `search: malformed searxng response (${key} is not an array)`,
    );
  }

  return value;
}

function encodeNames(
  kind: "categories" | "engines",
  value: unknown,
  listing: null | SearxngListing,
  parameters: URLSearchParams,
): void {
  if (value === undefined) return;

  if (!isStringArray(value)) {
    throw new TypeError(`search: ${kind} must be an array of strings`);
  }

  const names = value.map((name) => validateName(kind, name, listing));
  // SearXNG unions explicit engines with categories (webadapter.py
  // parse_generic), so both are always forwarded when supplied — one is
  // never a replacement for the other.
  if (names.length > 0) parameters.set(kind, names.join(","));
}

// A name SearXNG would drop silently (empty, whitespace-only, or unlisted
// on this instance) is rejected instead. SearXNG strips each name before
// its lookup (webadapter.py); here a padded name fails the exact listing
// match and is rejected rather than stripped.
function validateName(
  kind: "categories" | "engines",
  name: string,
  listing: null | SearxngListing,
): string {
  if (name.trim() === "") {
    throw new Error(`search: ${kind} entries must be non-empty strings`);
  }

  if (name.includes(",")) {
    // SearXNG splits the parameter on commas; a comma inside one name
    // would silently become two names.
    throw new Error(`search: ${kind} entries must not contain commas`);
  }

  const known =
    kind === "categories" ? listing?.categoryNames : listing?.engineNames;

  if (known !== undefined && !known.has(name)) {
    throw new Error(
      `search: ${kind} entry is not listed by this instance: ${name}`,
    );
  }

  return name;
}

// unresponsive_engines reasons worth one retry (searx/webutils.py
// exception_classname_to_text): timeouts, CAPTCHA/429/403 blocks,
// suspensions, and the proxy/connection/network/protocol failures of a bad
// Tor circuit. SearXNG round-robins its SOCKS5 proxy pool per request, so a
// retry lands on fresh exit circuits; HTTP, parsing, API, SSL, and crash
// errors would fail the same way again.
const TRANSIENT_ENGINE_ERROR =
  /timeout|too many requests|access denied|suspended|captcha|proxy error|connection error|network error|protocol error/i;

// GET /config is the only authoritative source of the category and engine
// names this instance accepts (33 categories, 261 engines today); the
// server keeps the first successful answer for the life of the process.
export function parseSearxngConfig(json: unknown): SearxngListing {
  if (!isRecord(json)) throw new Error("searxng config: not an object");
  const categories = json["categories"];

  if (!isStringArray(categories)) {
    throw new Error("searxng config: categories must be an array of strings");
  }

  const engines = json["engines"];

  if (
    !Array.isArray(engines) ||
    !engines.every(
      (engine): engine is { name: string } =>
        isRecord(engine) && isNonEmptyString(engine["name"]),
    )
  ) {
    throw new TypeError(
      "searxng config: engines must be an array of objects with a name",
    );
  }

  return {
    categoryNames: new Set(categories),
    engineNames: new Set(engines.map((engine) => engine.name)),
  };
}

// Retry only when the first envelope carries no payload (plugin answers
// and infoboxes count as payload) and every unresponsive engine failed
// transiently; partial failures and valid zero-result answers are
// returned as they are.
export function shouldRetryEnvelope(envelope: SearxEnvelope): boolean {
  return (
    !envelope.hasPayload &&
    envelope.unresponsiveEngines.length > 0 &&
    envelope.unresponsiveEngines.every(([, reason]) =>
      TRANSIENT_ENGINE_ERROR.test(reason),
    )
  );
}
