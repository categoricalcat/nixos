# mcp-searxng sidecar exposing the host's SearXNG over the Model Context
# Protocol (HTTP transport on 127.0.0.1:3001, MCP endpoint at /mcp), so
# OpenHands (and any other
# MCP-aware client on this host) can do private web search without going
# through the public htpasswd-protected vhost.
#
# Runs under podman (consistent with portainer.nix etc.).
# No bearer token in this minimal setup: bind is loopback-only.

{ addresses, ... }:

let
  sharedMcp = import ./ai/mcp.nix;
in

{
  virtualisation.oci-containers.containers.mcp-searxng = {
    autoStart = true;
    image = "isokoliuk/mcp-searxng:latest";
    ports = [ "${sharedMcp.searxng.host}:${toString sharedMcp.searxng.port}:3000" ];
    environment = {
      SEARXNG_URL = "http://${addresses.network.lan.ipv4.host}:8888";
      MCP_HTTP_PORT = "3000";
    };
    extraOptions = [
      "--pull=newer"
    ];
  };

  systemd.services."podman-mcp-searxng" = {
    wants = [
      "network-online.target"
      "podman.socket"
    ];
    after = [
      "network-online.target"
      "podman.socket"
      "searx.service"
    ];
    # Restart the sidecar whenever searx restarts so it never holds a stale
    # connection assumption. One-way: searx restarting bounces us, but searx
    # failing does not stop us permanently (unlike bindsTo).
    partOf = [ "searx.service" ];
  };
}
