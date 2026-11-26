// Firecrawl API access shared by the scrape and map tools: the HTTP call and
// the request-argument checks both tools apply.

import { isNonEmptyString, isRecord } from "./guards.ts";

const API = (
  process.env["FIRECRAWL_API_URL"] || "http://localhost:24002"
).replace(/\/$/, "");

// Scrape timeout ceiling (slow Playwright scrapes justify 120s). callApi adds
// 5s of fetch-abort headroom so Firecrawl can return its own timeout error
// before Node aborts the request.
export const API_TIMEOUT_MS = 120_000;

// Shapes read from Firecrawl API responses. Non-object bodies (including JSON
// `null`) fall back to {} in callApi so error handling always preserves the
// HTTP status code.
interface ApiResponse {
  data?: unknown;
  error?: unknown;
  links?: unknown;
  success?: unknown;
  warning?: unknown;
}

export async function callApi(
  path: string,
  body: unknown,
): Promise<ApiResponse> {
  const response = await fetch(`${API}${path}`, {
    body: JSON.stringify(body),
    headers: { "Content-Type": "application/json" },
    method: "POST",
    signal: AbortSignal.timeout(API_TIMEOUT_MS + 5000),
  });
  let json: ApiResponse = {};

  try {
    const parsed: unknown = await response.json();
    if (isRecord(parsed)) json = parsed;
  } catch {
    // An empty/invalid body stays {}; property access stays safe below.
  }

  if (!response.ok || json.success === false) {
    const error = json.error;
    throw new Error(
      isNonEmptyString(error) ? error : `firecrawl HTTP ${response.status}`,
    );
  }

  return json;
}

export function optionalBoolean(
  tool: string,
  arguments_: Record<string, unknown>,
  name: string,
): boolean | undefined {
  const value = arguments_[name];

  if (value !== undefined && typeof value !== "boolean") {
    throw new TypeError(`${tool}: ${name} must be a boolean`);
  }

  return value;
}

export function optionalInt(
  tool: string,
  arguments_: Record<string, unknown>,
  name: string,
  min: number,
  max: number,
): number | undefined {
  const value = arguments_[name];

  if (value === undefined) return undefined;

  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < min ||
    value > max
  ) {
    throw new Error(
      `${tool}: ${name} must be an integer in [${min}, ${max}], got: ${value}`,
    );
  }

  return value;
}

const LOCAL_FILE_HINT =
  "local files are read with the file tools, never through Firecrawl";

// Absolute http(s) URL only. Agents ask for `file://` (and bare paths) when
// they want a local file; Firecrawl answers those with an opaque "Bad
// Request", so reject them here with a message that names the right tool.
export function requireUrl(
  tool: string,
  arguments_: Record<string, unknown>,
): string {
  const url = arguments_["url"];

  if (!isNonEmptyString(url)) {
    throw new TypeError(`${tool}: url must be a non-empty string`);
  }

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error(
      `${tool}: url must be an absolute http(s) URL (${LOCAL_FILE_HINT}), got: ${url}`,
    );
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    const fileHint = parsed.protocol === "file:" ? `; ${LOCAL_FILE_HINT}` : "";
    throw new Error(
      `${tool}: ${parsed.protocol} is not supported (http and https only)${fileHint}`,
    );
  }

  // WHATWG URL strips surrounding whitespace/control chars and accepts
  // slashless special-scheme URLs like `http:foo`; reject them so we never
  // forward a malformed raw string to Firecrawl.
  if (
    !/^https?:\/\//i.test(url) ||
    url.trim() !== url ||
    /[\t\r\n]/.test(url)
  ) {
    throw new Error(
      `${tool}: url must be an absolute http(s) URL, got: ${url}`,
    );
  }

  return url;
}
