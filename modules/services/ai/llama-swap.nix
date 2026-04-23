{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.llama-swap-amdgpu;

  unstable = import ../../nixpkgs-unstable.nix { inherit inputs pkgs; };

  # Per-package override so the unstable helper stays generic; avoids the
  # global `nixpkgs.config.rocmSupport = true` that ollama-amdgpu had to set.
  llama-cpp = (unstable.llama-cpp.override {
    rocmSupport = true;
    rocmGpuTargets = cfg.rocmTargets;
  }).overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DGGML_HIP_UMA=ON"  # Required for APU/iGPU unified memory
    ];
  });
  llama-server = lib.getExe' llama-cpp "llama-server";

  ai = import ./models.nix;

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
        "--no-webui"
        # #region agent log
        "--log-file"
        "/var/log/llama-swap-dbg2/server.log"
        "--verbose"
        # #endregion
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
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.amdgpu.opencl.enable = true;

    services.llama-swap = {
      enable = true;
      package = unstable.llama-swap;
      inherit (cfg) port;
      settings = {
        healthCheckTimeout = 60;
        models = swapModels;
      };
    };

    # Persistent HuggingFace cache + GPU access for the spawned llama-server
    # children. SupplementaryGroups gives the DynamicUser access to /dev/dri
    # and /dev/kfd; LLAMA_CACHE pins downloads under CacheDirectory so they
    # survive reboots.
    #
    # ROCm sandboxing overrides:
    #   MemoryDenyWriteExecute → HIP JIT-compiles GPU kernels (needs W|X pages)
    #   PrivateUsers           → must see real UIDs for /dev/kfd group checks
    #   PrivateDevices         → must access /dev/kfd + /dev/dri/renderD128
    systemd.services.llama-swap.serviceConfig = {
      CacheDirectory = "llama-swap";
      # #region agent log
      LogsDirectory = "llama-swap-dbg2";
      LogsDirectoryMode = "0755";
      UMask = "0022";
      # Probe what GPU enumeration the SAME sandbox sees at startup.
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c '${llama-server} --list-devices > /var/log/llama-swap-dbg2/list-devices.log 2>&1 || true'"
      ];
      # #endregion
      SupplementaryGroups = [
        "video"
        "render"
      ];
      # Required for ROCm/HIP GPU access on the iGPU
      MemoryDenyWriteExecute = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      SystemCallFilter = lib.mkForce [];
      DeviceAllow = [
        "/dev/kfd rw"
        # systemd's device cgroup rules do not recursively grant access to
        # child character devices when only the parent directory is allowed.
        # ROCm needs the actual DRM nodes, otherwise `--list-devices` inside
        # the sandbox reports "no ROCm-capable device is detected".
        "/dev/dri/card0 rw"
        "/dev/dri/renderD128 rw"
      ];
      Environment = [
        "LLAMA_CACHE=/var/cache/llama-swap"
      ]
      ++ lib.optional (cfg.rocmOverrideGfx != null) "HSA_OVERRIDE_GFX_VERSION=${cfg.rocmOverrideGfx}";
    };
  };
}
