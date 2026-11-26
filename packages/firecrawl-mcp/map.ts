// The `map` tool: a site's links (sitemap + crawler) through the self-hosted
// Firecrawl API.

import {
  callApi,
  optionalBoolean,
  optionalInt,
  requireUrl,
} from "./firecrawl-api.ts";

const MAP_LIMIT_MAX = 100_000;

export const mapDefinition = {
  description:
    "Map a website to a list of its links (sitemap + crawler); " +
    "returns Firecrawl's JSON answer with the links array.",
  inputSchema: {
    additionalProperties: false,
    properties: {
      includeSubdomains: {
        description: "Map subdomains too (default true).",
        type: "boolean",
      },
      limit: {
        description: `Max links, integer 1-${MAP_LIMIT_MAX} (server default 5000).`,
        maximum: MAP_LIMIT_MAX,
        minimum: 1,
        type: "integer",
      },
      search: {
        description:
          "Rank links by similarity to this query (sorts returned links " +
          "rather than filtering them; limit cuts the list before ranking).",
        type: "string",
      },
      url: {
        description:
          "Base URL to map; absolute http(s) URL only (a site, never a " +
          "local path).",
        format: "uri",
        type: "string",
      },
    },
    required: ["url"],
    type: "object",
  },
};

export async function map(
  arguments_: Record<string, unknown>,
): Promise<string> {
  const json = await callApi("/v2/map", mapRequest(arguments_));
  // { success, id, links, warning? }; the answer is passed through whole,
  // warning included, so a base-domain hint never hides from the agent.
  if (!Array.isArray(json.links))
    throw new TypeError("map: response carried no links");
  return JSON.stringify(json);
}

// Mirrors upstream v2.11.0 zod: url required; search (string),
// includeSubdomains (boolean, default true) and limit (1..MAP_LIMIT_MAX,
// default 5000) optional. Upstream takes any number for limit; a fractional
// link count means nothing, so it must be an integer here.
function mapRequest(arguments_: Record<string, unknown>) {
  const url = requireUrl("map", arguments_);
  const search = arguments_["search"];

  if (search !== undefined && typeof search !== "string") {
    throw new TypeError("map: search must be a string");
  }

  const includeSubdomains = optionalBoolean(
    "map",
    arguments_,
    "includeSubdomains",
  );
  const limit = optionalInt("map", arguments_, "limit", 1, MAP_LIMIT_MAX);
  return {
    url,
    ...(search !== undefined && { search }),
    ...(includeSubdomains !== undefined && { includeSubdomains }),
    ...(limit !== undefined && { limit }),
  };
}
