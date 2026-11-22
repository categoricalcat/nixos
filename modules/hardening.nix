# The shared systemd hardening baseline and the inventory the
# hardening-baseline contract (nix/checks.nix) enforces: custom long-running
# units either satisfy every baseline key (scalar keys equal it;
# RestrictAddressFamilies may be a subset; SystemCallFilter may only append `~`
# deny groups), or carry `minus` with the exact keys they drop/weaken and why,
# or are `exempt` with a reason. An entry with no keys means "full baseline, no
# exceptions". Upstream-hardened units (nginx, postgresql, exporters, forgejo,
# ...) are deliberately absent: the contract guards our attrset spreads
# (modules using the `_module.args.systemdHardening` convention), not
# upstream's own hardening choices.
let
  servarrMinus = {
    minus = [
      "ProtectSystem"
      "MemoryDenyWriteExecute"
      "SystemCallFilter"
    ];
    why = "writes /persist/media, JITs, and needs @chown; upstream lidarr/readarr/prowlarr modules set none of the baseline (modules/services/arr/default.nix)";
  };
  nodeMinus = {
    minus = [
      "MemoryDenyWriteExecute"
      "SystemCallFilter"
    ];
    why = "Node.js JIT needs writable executable mappings and its fs layer uses @chown (modules/services/{arr/default,ai/sillytavern}.nix)";
  };
  gpuMinus = {
    minus = [ "PrivateDevices" ];
    why = "Vulkan needs the DRM render node (modules/services/ai/{llama-cpp,sd-cpp}.nix)";
  };
  smartdMinus = {
    minus = [
      "CapabilityBoundingSet"
      "PrivateDevices"
    ];
    why = "SMART transports need CAP_SYS_RAWIO and real disk nodes (modules/server-settings.nix)";
  };
in
{
  baseline = {
    CapabilityBoundingSet = "";
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectProc = "invisible";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
  };

  units = {
    yifuwuqi = {
      attic-watch-store = { };
      cadvisor = {
        minus = [
          "CapabilityBoundingSet"
          "ProtectHome"
          "ProtectProc"
          "RestrictAddressFamilies"
          "RestrictNamespaces"
        ];
        why = "must see every PID, enter container namespaces, read /home for fs stats, and open AF_NETLINK; capabilities stay unset for delegated cgroup reads (modules/services/monitoring/workload-metrics.nix)";
      };
      docs = { };
      docs-watcher = { };
      lidarr = servarrMinus;
      readarr = servarrMinus;
      prowlarr = servarrMinus;
      seerr = nodeMinus;
      llama-cpp = gpuMinus;
      llama-cpp-idle-unload = { };
      loki = {
        minus = [ "RestrictAddressFamilies" ];
        why = "Go ring/memberlist interface autodetect needs AF_NETLINK (modules/services/monitoring/loki.nix)";
      };
      vector = { };
      opencode = {
        minus = [
          "ProtectSystem"
          "ProtectHome"
          "PrivateDevices"
          "RestrictNamespaces"
          "MemoryDenyWriteExecute"
        ];
        why = "agent runtime reads/writes its home tree (ProtectSystem=full), spawns PTYs/sandboxes, and JITs (modules/services/opencode.nix)";
      };
      sillytavern = nodeMinus;
      smartd = smartdMinus;
      cockpit.exempt = "upstream ships its own set; PAM logins need setuid paths (modules/services/cockpit.nix)";
      podman.exempt = "rootful container runtime needs capabilities, namespaces and real /dev (modules/virtualisation/podman.nix)";
    };

    yirukou = {
      goaccess = { };
      vector = { };
      smartd = smartdMinus;
    };

    yitaishi = {
      llama-cpp = gpuMinus;
      llama-cpp-idle-unload = { };
      sd-cpp = gpuMinus;
      sd-cpp-fetch = { };
    };
  };
}
