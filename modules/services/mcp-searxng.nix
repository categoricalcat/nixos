# mcp-searxng sidecar exposing the host's SearXNG over the Model Context
# Protocol (HTTP transport on 127.0.0.1:3001), so OpenHands (and any other
# MCP-aware client on this host) can do private web search without going
# through the public htpasswd-protected vhost.
#
# Runs under podman (consistent with portainer.nix etc.).
# No bearer token in this minimal setup: bind is loopback-only.

_:

{
  virtualisation.oci-containers.containers.mcp-searxng = {
    autoStart = true;
    image = "isokoliuk/mcp-searxng:latest";
    ports = [ "127.0.0.1:3001:3000" ];
    environment = {
      SEARXNG_URL = "http://host.containers.internal:8888";
      MCP_HTTP_PORT = "3000";
    };
    extraOptions = [
      "--pull=newer"
      "--add-host=host.containers.internal:host-gateway"
    ];
  };

  systemd.services."podman-mcp-searxng" = {
    wants = [
      "network-online.target"
      "podman.socket"
      "searx.service"
    ];
    after = [
      "network-online.target"
      "podman.socket"
      "searx.service"
    ];
  };
}
