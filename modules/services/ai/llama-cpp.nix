# Per-model llama.cpp servers driven by the models.nix registry.
#
# For every enabled registry entry whose `targetHost` matches this host and
# which declares a `port`, one systemd unit `llama-cpp-<name>` runs a
# dedicated llama-server. The GGUF is pulled from HuggingFace on first start
# into the shared LLAMA_CACHE.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-cpp-node;
  ai = import ./models.nix;

  package =
    if cfg.backend == "vulkan" then
      pkgs.llama-cpp.override { vulkanSupport = true; }
    else
      pkgs.llama-cpp.override { rocmSupport = true; };

  localModels = lib.filterAttrs (
    _n: m: (m.targetHost or null) == config.networking.hostName && m ? port
  ) ai.local.models;

  sanitize = lib.replaceStrings [ ":" "." ] [ "-" "-" ];

  mkUnit = name: m: {
    description = "llama.cpp server for ${name} (${m.llamaCpp.hfRepo}:${m.llamaCpp.quant})";
    # First start downloads the GGUF from HuggingFace.
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # HF cache; also HOME so Mesa/RADV gets a writable shader cache (a
    # DynamicUser's HOME is /, read-only).
    environment.LLAMA_CACHE = "/var/cache/llama-cpp";
    environment.HOME = "/var/cache/llama-cpp";

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${package}/bin/llama-server"
        "-hf ${m.llamaCpp.hfRepo}:${m.llamaCpp.quant}"
        "--host 127.0.0.1"
        "--port ${toString m.port}"
        "-ngl 99"
        "-fa on"
        "--cache-type-k q8_0"
        "--cache-type-v q8_0"
        "--jinja"
        "-c ${toString m.contextLength}"
        "--no-webui"
        "--sleep-idle-seconds 300"
      ];
      CacheDirectory = "llama-cpp";
      DynamicUser = true;
      User = "llama-cpp";
      SupplementaryGroups = [
        "video"
        "render"
      ];
      Restart = "on-failure";
    };
  };
in
{
  options.services.llama-cpp-node = {
    enable = lib.mkEnableOption "per-model llama.cpp servers from the models.nix registry";

    backend = lib.mkOption {
      type = lib.types.enum [
        "vulkan"
        "rocm"
      ];
      default = "vulkan";
      description = "GPU backend llama.cpp is built with.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Registers the RADV ICD under /run/opengl-driver so llama-server finds
    # the Vulkan driver without VK_DRIVER_FILES hacks.
    hardware.graphics.enable = true;

    systemd.services = lib.mapAttrs' (
      n: m: lib.nameValuePair "llama-cpp-${sanitize n}" (mkUnit n m)
    ) localModels;
  };
}
