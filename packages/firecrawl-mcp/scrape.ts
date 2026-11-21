// The `scrape` tool: one URL through the self-hosted Firecrawl API, exposing
// only the options this deployment serves.

import {
  API_TIMEOUT_MS,
  callApi,
  optionalBoolean,
  optionalInt,
  requireUrl,
} from "./firecrawl-api.ts";
import { isNonEmptyString, isRecord } from "./guards.ts";

// Formats this deployment serves, in schema-enum order. `summary` needs an
// LLM and `audio`/`video`/`redactPII` need fire services this instance does
// not run, so they stay out of the tool.
const SCRAPE_FORMATS = ["markdown", "html", "rawHtml", "links", "images"];
const SCRAPE_TIMEOUT_MIN_MS = 1000;
const WAIT_FOR_MAX_MS = 60_000;

export const scrapeDefinition = {
  description:
    "Scrape a single URL and return its markdown (default), or the whole " +
    "document as JSON when formats beyond markdown are requested.",
  inputSchema: {
    additionalProperties: false,
    properties: {
      excludeTags: {
        description: "CSS selectors of elements to drop.",
        items: { type: "string" },
        type: "array",
      },
      formats: {
        description:
          "Output formats; default markdown. rawHtml is unmodified page " +
          "source (ignores onlyMainContent/includeTags/excludeTags).",
        items: { enum: SCRAPE_FORMATS, type: "string" },
        type: "array",
      },
      includeTags: {
        description: "CSS selectors of elements to keep.",
        items: { type: "string" },
        type: "array",
      },
      onlyMainContent: {
        description: "Drop boilerplate (default true).",
        type: "boolean",
      },
      timeout: {
        description: `Per-scrape budget in ms, integer ${SCRAPE_TIMEOUT_MIN_MS}-${API_TIMEOUT_MS}.`,
        maximum: API_TIMEOUT_MS,
        minimum: SCRAPE_TIMEOUT_MIN_MS,
        type: "integer",
      },
      url: { description: "Page to scrape.", format: "uri", type: "string" },
      waitFor: {
        description: `Wait ms after load, integer 0-${WAIT_FOR_MAX_MS}; at most half of timeout when both are set.`,
        maximum: WAIT_FOR_MAX_MS,
        minimum: 0,
        type: "integer",
      },
    },
    required: ["url"],
    type: "object",
  },
};

export async function scrape(
  arguments_: Record<string, unknown>,
): Promise<string> {
  const request = scrapeRequest(arguments_);
  const json = await callApi("/v2/scrape", request);
  const data = json.data;
  if (!isRecord(data))
    throw new Error(`scrape: ${request.url} returned no data`);

  // A returned format requested beyond markdown sends the whole document, so
  // no requested format hides behind the markdown text.
  if (
    request.formats?.some(
      (format) => format !== "markdown" && Object.hasOwn(data, format),
    )
  ) {
    return JSON.stringify(data);
  }

  const markdown = data["markdown"];

  if (isNonEmptyString(markdown)) {
    // The engine warns on degraded renders (e.g. stealthProxy fallback);
    // partial content must not silently pass as complete.
    const warning = data["warning"];
    return isNonEmptyString(warning)
      ? `${markdown}\n\n[firecrawl warning] ${warning}`
      : markdown;
  }

  // Firecrawl answers 200/success:true with empty markdown when an engine
  // fails to render; the reason hides in warning/metadata.error. Surface it
  // instead of handing the agent an empty result.
  const metadata = data["metadata"];
  const reasons = [
    data["warning"],
    isRecord(metadata) ? metadata["error"] : undefined,
  ].filter((reason) => isNonEmptyString(reason));
  throw new Error(
    `scrape: ${request.url} returned no content` +
      (reasons.length > 0 ? ` (${reasons.join("; ")})` : ""),
  );
}

// Mirrors upstream v2.11.0 zod: waitFor int 0..WAIT_FOR_MAX_MS, timeout int
// >= SCRAPE_TIMEOUT_MIN_MS with waitFor <= timeout/2 when both are set.
function scrapeRequest(arguments_: Record<string, unknown>) {
  const url = requireUrl("scrape", arguments_);
  // validateScrapeFormats covers both the non-array and the bad-entry case.
  const formats = arguments_["formats"];
  const includeTags = stringArray(arguments_, "includeTags");
  const excludeTags = stringArray(arguments_, "excludeTags");
  const onlyMainContent = optionalBoolean(
    "scrape",
    arguments_,
    "onlyMainContent",
  );
  const waitFor = optionalInt(
    "scrape",
    arguments_,
    "waitFor",
    0,
    WAIT_FOR_MAX_MS,
  );
  const timeout = optionalInt(
    "scrape",
    arguments_,
    "timeout",
    SCRAPE_TIMEOUT_MIN_MS,
    API_TIMEOUT_MS,
  );

  if (waitFor !== undefined && timeout !== undefined && waitFor > timeout / 2) {
    throw new Error("scrape: waitFor must not exceed half of timeout");
  }

  return {
    url,
    ...(formats !== undefined && { formats: validateScrapeFormats(formats) }),
    ...(includeTags !== undefined && { includeTags }),
    ...(excludeTags !== undefined && { excludeTags }),
    ...(onlyMainContent !== undefined && { onlyMainContent }),
    ...(waitFor !== undefined && { waitFor }),
    ...(timeout !== undefined && { timeout }),
  };
}

// includeTags/excludeTags only; the tool name in the message is fixed
// accordingly.
function stringArray(
  arguments_: Record<string, unknown>,
  name: string,
): string[] | undefined {
  const value = arguments_[name];
  if (value === undefined) return undefined;

  if (
    !Array.isArray(value) ||
    value.some((entry) => typeof entry !== "string" || entry.trim() === "")
  ) {
    throw new Error(`scrape: ${name} must be an array of non-empty strings`);
  }

  return value;
}

function validateScrapeFormats(formats: unknown): string[] {
  if (
    !Array.isArray(formats) ||
    formats.length === 0 ||
    formats.some(
      (format) =>
        !(typeof format === "string" && SCRAPE_FORMATS.includes(format)),
    )
  ) {
    throw new Error(
      `scrape: formats must be a non-empty array of: ${SCRAPE_FORMATS.join(", ")}`,
    );
  }

  return formats;
}
