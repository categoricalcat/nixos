# AI Research Engine Architecture Plan

Provide a brief description of the problem, any background context, and what the change accomplishes.
This plan outlines the architecture for a fully self-hosted, open-source AI Research Engine. The goal is to replace the reliance on Exa (a proprietary search API) with a local stack that can perform general web searches, deep academic research, and AI-friendly content crawling, while bypassing anti-bot protections.

We will achieve this by deploying **Firecrawl** and configuring it to use our existing **SearXNG** instance as its internal search provider. Finally, we will connect the official Firecrawl MCP server to OpenCode, giving the AI a single, unified tool to handle "Search + Scrape" autonomously.

## Hardware Review
>
> [!IMPORTANT]
> **Hardware Requirements for Firecrawl:** Firecrawl runs several heavy background workers (Playwright/Chrome) to render JavaScript and bypass bot protections. Please confirm that your NixOS host has sufficient RAM (minimum 8GB recommended) to handle concurrent headless browser sessions.

## Proposed Changes

### SearXNG Configuration Validation

Ensure that SearXNG is properly configured to act as an API backend for Firecrawl and is tuned for academic research.

#### [MODIFY] SearXNG NixOS Module (`modules/services/searxng.nix`)

Your SearXNG configuration already includes `json` formats, which is required. We just need to add the academic and general engines to `services.searx.settings.engines`. Note that `google` is intentionally omitted or disabled because it hands out CAPTCHAs to Tor exit nodes.

```nix
services.searx.settings.engines = [
  {
    name = "duckduckgo";
    engine = "duckduckgo";
    shortcut = "ddg";
    categories = "general";
    disabled = false;
  }
  {
    name = "mojeek";
    disabled = false;
    shortcut = "mjk";
    categories = "general";
  }
  {
    name = "google scholar";
    engine = "google_scholar";
    shortcut = "gs";
    categories = "science";
    disabled = false;
  }
  {
    name = "arxiv";
    engine = "arxiv";
    shortcut = "ar";
    categories = "science";
    disabled = false;
  }
];
```

---

### Firecrawl Deployment Stack

Deploy Firecrawl and explicitly route its internal search endpoint to your local SearXNG instance.

#### [NEW] Firecrawl NixOS Module (`modules/services/firecrawl.nix`)

We will deploy Firecrawl natively using `virtualisation.oci-containers` integrated into the NixOS configuration.

```nix
{
  virtualisation.oci-containers.containers.firecrawl = {
    image = "mendableai/firecrawl:latest";
    ports = [ "3002:3002" ];
    environment = {
      PORT = "3002";
      REDIS_URL = "redis://redis:6379";
      POSTGRES_URL = "postgresql://postgres:postgres@postgres:5432/firecrawl";
      
      # SearXNG Search Integration
      SEARCH_PROVIDER = "searxng";
      SEARXNG_BASE_URL = "http://localhost:8888"; # SearXNG runs on 8888 in your config
      SEARXNG_ENDPOINT = "http://localhost:8888";
      SEARXNG_CATEGORIES = "science,general";
    };
    # dependsOn = [ "firecrawl-redis" "firecrawl-postgres" ];
  };
}
```

*(Note: You will also need to declare the `firecrawl-redis` and `firecrawl-postgres` containers or native NixOS services for Redis and PostgreSQL).*

---

### OpenCode MCP Integration

Attach the Firecrawl MCP server to your OpenCode environment so the agent can autonomously trigger the Search+Scrape workflow.

#### [MODIFY] OpenCode MCP Config (`.opencode/mcp.json` or equivalent)

```json
{
  "mcpServers": {
    "firecrawl": {
      "command": "npx",
      "args": [
        "-y",
        "@mendable/firecrawl-mcp-server"
      ],
      "env": {
        "FIRECRAWL_API_URL": "http://localhost:3002",
        "FIRECRAWL_API_KEY": "YOUR_FIRECRAWL_KEY" 
      }
    }
  }
}
```

*(Note: If you are running Firecrawl completely locally without auth enabled, you can pass a dummy key like `this_is_just_a_dummy_key`).*

## Verification Plan

### Automated/Local Tests

Once the containers/services are running, verify the integration manually before handing it to OpenCode.

1. **Test Firecrawl Search Endpoint** (Ensure it queries SearXNG):

```bash
curl -X POST "http://localhost:3002/v1/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "NixOS flakes tutorial",
    "limit": 3
  }'
```

1. **Test Firecrawl Scrape Endpoint** (Ensure Playwright renders and bypasses bots):

```bash
curl -X POST "http://localhost:3002/v1/scrape" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://nixos.wiki/wiki/Flakes",
    "formats": ["markdown"]
  }'
```

### Manual Verification

1. Open OpenCode.
2. Prompt the AI: *"Search for a recent academic paper on [Topic] and read its contents to summarize the methodology."*
3. Verify in the Firecrawl Bull-Board UI (`http://localhost:3002/admin/queues`) that a crawl job was successfully queued and completed.
