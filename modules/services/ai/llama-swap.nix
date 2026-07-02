{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-swap-amdgpu;
  enabled = cfg.enable || cfg.rpcServer.enable;

  # Per-package override so the unstable helper stays generic; avoids the
  # global `nixpkgs.config.rocmSupport = true` that ollama-amdgpu had to set.
  llama-cpp =
    (pkgs.llama-cpp.override {
      rocmSupport = true;
      rpcSupport = true;
      rocmGpuTargets = cfg.rocmTargets;
    }).overrideAttrs
      (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ lib.optional cfg.uma "-DGGML_HIP_UMA=ON";
        postInstall =
          builtins.replaceStrings
            [ "cp bin/rpc-server $out/bin/llama-rpc-server" ]
            [ "ln -s $out/bin/ggml-rpc-server $out/bin/llama-rpc-server" ]
            old.postInstall;
      });
  llama-server = lib.getExe' llama-cpp "llama-server";
  llama-rpc-server = lib.getExe' llama-cpp "llama-rpc-server";

  ai = import ./models.nix;
  vpnDeps =
    # lib.optional config.services.tailscale.enable "tailscaled.service" ++
    lib.optional config.services.netbird.enable "netbird.service";
  rpcEnabledFor = m: cfg.rpcPeers != [ ] && (m.rpc or true);
  deviceAllow = [ "/dev/kfd rw" ] ++ map (node: "${node} rw") cfg.drmDevices;
  rocmEnvironment =
    cacheDir:
    [ "LLAMA_CACHE=${cacheDir}" ]
    ++ lib.optional (cfg.rocmOverrideGfx != null) "HSA_OVERRIDE_GFX_VERSION=${cfg.rocmOverrideGfx}";
  # Reuse the ROCm-specific sandbox overrides for both llama-swap and the
  # rpc worker so the device-cgroup fix can't drift between the two services.
  rocmServiceConfig = {
    SupplementaryGroups = [
      "video"
      "render"
    ];
    MemoryDenyWriteExecute = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
    PrivateDevices = lib.mkForce false;
    SystemCallFilter = lib.mkForce [ ];
    DeviceAllow = deviceAllow;
  };

  # `${PORT}` is a llama-swap placeholder substituted at request time, not a
  # Nix interpolation -- escape the `$` so it survives into the YAML config.
  # #region agent log
  # DEBUG: --log-file + --verbose capture HIP/ROCm init output for the
  # spawned llama-server, since llama-swap eats stdout/stderr from children.
  # Sanitize model name for filename (replace ':' since it breaks some FS ops).
  # #endregion
  buildCmd =
    m:
    lib.concatStringsSep " " (
      [
        llama-server
        "--port"
        "\${PORT}"
        "-hf"
        "${m.llamaCpp.hfRepo}:${m.llamaCpp.quant}"
        "-ngl"
        "99"
        "-fa"
        "on"
        # Q8 KV cache. Halves the KV memory budget vs FP16 with no
        # measurable quality or throughput cost (per ggerganov/llama.cpp
        # benchmarks). This is the only reason 128k+ contexts fit on the
        # 7900 XTX after model weights. Q8 V cache requires flash-attn
        # built with all-quants support; the unstable nixpkgs llama-cpp
        # ships this for ROCm by default.
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--no-webui"
        # #region agent log
        "--log-file"
        "/var/log/llama-swap-dbg2/server.log"
        "--verbose"
        # #endregion
      ]
      ++ lib.optionals (rpcEnabledFor m) [
        "--rpc"
        (lib.concatStringsSep "," cfg.rpcPeers)
      ]
      ++ lib.optionals (rpcEnabledFor m && cfg.tensorSplit != null) [
        "--tensor-split"
        cfg.tensorSplit
      ]
      ++ lib.optional (m.tools or false) "--jinja"
      ++ lib.optionals (m.reasoning or false) [
        "--reasoning-format"
        "deepseek"
      ]
      ++ lib.optionals ((m.contextLength or 0) > 0) [
        "-c"
        (toString m.contextLength)
      ]
      # YaRN context extension for models whose target context exceeds
      # their native training window (Qwen 32k -> 64k/128k). Only emitted
      # when `yarn` is set; models native to the target context (gpt-oss,
      # qwen3-coder, deepseek-r1, granite4, gemma3) skip this entirely
      # because YaRN slightly degrades short-context quality for no gain.
      ++ lib.optionals (m ? yarn) [
        "--rope-scaling"
        "yarn"
        "--rope-scale"
        (toString m.yarn.scale)
        "--yarn-orig-ctx"
        (toString m.yarn.origCtx)
      ]
    );

  swapModels = lib.mapAttrs (_n: m: {
    cmd = buildCmd m;
    ttl = m.ttl or 600;
  }) ai.local.models;
in
{
  options.services.llama-swap-amdgpu = {
    enable = lib.mkEnableOption "llama-swap with ROCm llama.cpp backend";

    rocmTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "ROCm GPU targets to compile llama.cpp for (e.g. [ \"gfx1035\" ]).";
    };

    rocmOverrideGfx = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HSA_OVERRIDE_GFX_VERSION reported to the ROCm runtime.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Listen port for llama-swap (defaults to Ollama's port for drop-in API compat).";
    };

    rpcPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "RPC worker endpoints passed to llama.cpp via `--rpc`.";
    };

    tensorSplit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional llama.cpp `--tensor-split` value used when RPC peers are enabled.";
    };

    uma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GGML's HIP UMA path for APUs / iGPUs with unified memory.";
    };

    drmDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/dev/dri/card0"
        "/dev/dri/renderD128"
      ];
      description = "Explicit DRM device nodes to allow inside the systemd sandbox for ROCm.";
    };

    rpcServer = {
      enable = lib.mkEnableOption "llama.cpp RPC worker service";

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address for llama-rpc-server to bind to.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 50052;
        description = "Listen port for llama-rpc-server.";
      };

      cacheDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/cache/llama-rpc-server";
        description = "Runtime cache path exposed to llama-rpc-server via LLAMA_CACHE.";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "ROCm0" ];
        description = ''
          Restrict which detected devices llama-rpc-server exposes
          (passed via repeated `--device` flags). Empty list exposes all.
          Required when the host has multiple ROCm devices but
          `rocmGpuTargets` only covers a subset, otherwise tensor
          dispatches to a missing-kernel device SEGV the worker.
        '';
      };
    };
  };

  config = lib.mkIf enabled (
    lib.mkMerge [
      {
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };

        hardware.amdgpu.opencl.enable = true;
      }

      (lib.mkIf cfg.enable {
        services.llama-swap = {
          enable = true;
          package = pkgs.llama-swap;
          inherit (cfg) port;
          settings = {
            healthCheckTimeout = 120;
            models = swapModels;
          };
        };

        systemd.services.llama-swap = {
          after = [ "network-online.target" ] ++ vpnDeps;
          wants = [ "network-online.target" ] ++ vpnDeps;

          # Persistent HuggingFace cache + GPU access for the spawned
          # llama-server children. The debug probe stays in place because it
          # already proved essential for diagnosing ROCm-in-sandbox issues.
          serviceConfig = rocmServiceConfig // {
            CacheDirectory = "llama-swap";
            # #region agent log
            LogsDirectory = "llama-swap-dbg2";
            LogsDirectoryMode = "0755";
            UMask = "0022";
            ExecStartPre = [
              "${pkgs.bash}/bin/bash -c '${llama-server} --list-devices > /var/log/llama-swap-dbg2/list-devices.log 2>&1 || true'"
            ];
            # #endregion
            Environment = rocmEnvironment "/var/cache/llama-swap";
          };
        };
      })

      (lib.mkIf cfg.rpcServer.enable {
        systemd.services.llama-rpc-server = {
          description = "llama.cpp RPC worker";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ] ++ vpnDeps;
          wants = [ "network-online.target" ] ++ vpnDeps;

          serviceConfig = rocmServiceConfig // {
            Type = "simple";
            DynamicUser = true;
            # llama.cpp's rpc-server exits with status 0 even when bind fails
            # ("Failed to create server socket"), so on-failure leaves the
            # worker permanently dead after a transient bind error. Always
            # restart so a late tailscale IP assignment recovers on its own.
            Restart = "always";
            RestartSec = "5s";
            ExecStart = lib.concatStringsSep " " (
              [
                llama-rpc-server
                "--host"
                cfg.rpcServer.listenAddress
                "-p"
                (toString cfg.rpcServer.port)
                "-c"
              ]
              ++ lib.concatMap (d: [
                "--device"
                d
              ]) cfg.rpcServer.devices
            );
            CacheDirectory = "llama-rpc-server";
            LogsDirectory = "llama-rpc-server";
            LogsDirectoryMode = "0755";
            UMask = "0022";
            ExecStartPre = [
              "${pkgs.bash}/bin/bash -c '${llama-server} --list-devices > /var/log/llama-rpc-server/list-devices.log 2>&1 || true'"
            ];
            Environment = rocmEnvironment cfg.rpcServer.cacheDir;
          };
        };
      })
    ]
  );
}
