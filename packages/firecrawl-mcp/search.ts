// The `search` tool: queries the local SearXNG JSON API through the 1:1,
// lossless parameter contract in searxng-contract.ts and returns SearXNG's
// whole JSON answer verbatim. Firecrawl's own searxng adapter forwards only
// query/language/page with categories pinned by env, so it cannot serve
// per-request filters; nothing here calls that path.

import {
  encodeSearchQuery,
  MAX_TIMEOUT_LIMIT,
  parseSearxEnvelopeBody,
  parseSearxngConfig,
  type SearxngListing,
  shouldRetryEnvelope,
  TIME_RANGES,
} from "./searxng-contract.ts";

const SEARXNG = (process.env["SEARXNG_URL"] || "").replace(/\/$/, "");

// The instance's accepted category/engine names, read from GET /config.
// Only the first success is kept for the life of the process; a failure
// means the schemas and validators run unconstrained until a later call
// succeeds. The state box carries the memo so the reset-on-failure (a
// property write, not a variable rebinding) stays inside instanceListing.
const listingState: { cached: null | Promise<null | SearxngListing> } = {
  cached: null,
};

const fetchInstanceConfig = async (): Promise<null | SearxngListing> => {
  if (SEARXNG === "") return null;

  try {
    const response = await fetch(`${SEARXNG}/config`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return null;
    const json: unknown = await response.json();
    return parseSearxngConfig(json);
  } catch {
    return null;
  }
};

export const instanceListing = async (): Promise<null | SearxngListing> => {
  const pending = (listingState.cached ??= fetchInstanceConfig());
  const listing = await pending;

  if (listing === null && listingState.cached === pending) {
    listingState.cached = null;
  }

  return listing;
};

export const searchDefinition = (listing: null | SearxngListing) => ({
  description:
    "Search the web via the local SearXNG. Every parameter maps 1:1 " +
    "to SearXNG's Search API and keeps its meaning: categories and " +
    "engines are unioned, time_range always applies, language is " +
    "'auto' or e.g. en / pt-BR, pageno >= 1, " +
    `timeout_limit caps engine seconds in (0, ${MAX_TIMEOUT_LIMIT}], ` +
    "and safesearch stays off (pinned to 0). " +
    "The response is " +
    "SearXNG's whole JSON answer verbatim: results plus answers, " +
    "infoboxes, suggestions, corrections, unresponsive_engines.",
  inputSchema: {
    additionalProperties: false,
    properties: {
      categories: {
        description:
          "Result categories; names the instance lists at GET /config. " +
          "Unlisted names are rejected, not dropped.",
        // The enum constrains the items, so it lives there.
        items: {
          ...(listing !== null && { enum: [...listing.categoryNames] }),
          type: "string",
        },
        type: "array",
      },
      engines: {
        description:
          "Engine names from the instance's GET /config listing (not " +
          "shortcuts); unioned with categories, never a replacement for them.",
        items: { type: "string" },
        type: "array",
      },
      language: {
        description: "'auto', or a code like en / pt-BR (pt_BR accepted).",
        type: "string",
      },
      pageno: {
        description: "1-indexed result page (safe integer).",
        minimum: 1,
        type: "integer",
      },
      query: {
        description: "Search query, passed through unchanged.",
        minLength: 1,
        type: "string",
      },
      time_range: {
        description: "Restrict results to this period; always applies.",
        enum: [...TIME_RANGES],
        type: "string",
      },
      timeout_limit: {
        description:
          `Max seconds engines may take, finite in (0, ${MAX_TIMEOUT_LIMIT}]; ` +
          `the instance caps above ${MAX_TIMEOUT_LIMIT} and times every ` +
          "engine out at 0.",
        exclusiveMinimum: 0,
        maximum: MAX_TIMEOUT_LIMIT,
        type: "number",
      },
    },
    required: ["query"],
    type: "object",
  },
});

export async function search(
  arguments_: Record<string, unknown>,
): Promise<string> {
  if (SEARXNG === "") throw new Error("search: SEARXNG_URL is not configured");
  const listing = await instanceListing();
  const searchParameters = encodeSearchQuery(arguments_, listing);
  let body = await querySearx(searchParameters);

  if (shouldRetryEnvelope(parseSearxEnvelopeBody(body))) {
    // SearXNG round-robins its Tor SOCKS5 pool per request, so a single
    // retry lands on fresh exit circuits when every engine hit a
    // transient error.
    body = await querySearx(searchParameters);
    // The retried body passes the same shape validation (throws on malformed).
    parseSearxEnvelopeBody(body);
  }

  return body;
}

async function querySearx(searchParameters: URLSearchParams): Promise<string> {
  const response = await fetch(`${SEARXNG}/search?${searchParameters}`, {
    // SearXNG caps engine waits at max_request_timeout (15s); 20s per attempt
    // bounds a hung fetch while leaving headroom for a single retry.
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`searxng HTTP ${response.status}`);
  return await response.text();
}
