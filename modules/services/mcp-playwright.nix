# Playwright MCP sidecar exposing the official Microsoft container's
# headless Chromium over the Model Context Protocol (HTTP transport on
# 127.0.0.1:3002, MCP endpoint at /mcp), so opencode (and any other
# MCP-aware client on this host) can drive a real browser without
# pulling chromium into the NixOS closure.
#
# Why a container and not pkgs.chromium directly:
#   yifuwuqi runs nixpkgs-small, whose binary cache deliberately
#   excludes large packages (chromium, firefox, ...). Putting
#   `pkgs.chromium` into the system closure triggers a 50k+ unit
#   chromium source build. Running the official upstream image keeps
#   chromium entirely outside `/nix/store`.
#
# Network shape:
#   - Loopback port-map only (`127.0.0.1:3002:8931`). No --network=host.
#   - Container reaches the internet via the default podman bridge.
#   - --shm-size=2g instead of --ipc=host, so the host's IPC namespace
#     is also not shared (the standard playwright-in-docker advice is
#     `--ipc=host`, but `--shm-size` is the no-namespace-sharing
#     equivalent and is sufficient for a single-tab MCP workload).

_:

let
  sharedMcp = import ./ai/mcp.nix;
in

{
  virtualisation.oci-containers.containers.mcp-playwright = {
    autoStart = true;
    image = "mcr.microsoft.com/playwright/mcp:latest";
    ports = [
      "${sharedMcp.playwright.host}:${toString sharedMcp.playwright.port}:8931"
    ];

    # The image's default entrypoint already runs:
    #   node /app/cli.js --headless --browser chromium --no-sandbox
    # so we only append the HTTP-transport flags + isolated profile.
    cmd = [
      "--port"
      "8931"
      "--host"
      "0.0.0.0"
      # In-memory profile per session; no podman volume needed.
      "--isolated"
      # Disable DNS rebinding protection. The default host check rejects
      # any request whose `Host` header doesn't match the bind target
      # (here `0.0.0.0:8931` -> effectively `localhost:8931` only), so
      # opencode connecting via `127.0.0.1:3002` gets a 403. The
      # protection exists to stop malicious *web pages* from tricking a
      # browser into hitting the MCP via DNS games, but the only client
      # here is opencode over loopback (the host port is bound to
      # 127.0.0.1, not exposed externally), so `*` is the right choice.
      "--allowed-hosts"
      "*"
    ];

    extraOptions = [
      # Always pull a newer manifest if available, mirrors the
      # mcp-searxng container policy.
      "--pull=newer"
      # Reap zombies. Required by upstream playwright Docker docs --
      # without --init the node process inherits PID 1 semantics and
      # leaks defunct chromium helpers.
      "--init"
      # Chromium needs sizeable /dev/shm; the upstream recommendation
      # is `--ipc=host`, but that shares the host IPC namespace. 2 GiB
      # is plenty for a single-context headless browser.
      "--shm-size=2g"
    ];
  };

  systemd.services."podman-mcp-playwright" = {
    wants = [
      "network-online.target"
      "podman.socket"
    ];
    after = [
      "network-online.target"
      "podman.socket"
    ];
  };
}
