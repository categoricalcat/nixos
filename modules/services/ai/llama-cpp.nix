# On-demand llama.cpp router server driven by modules/services/ai/models.nix.
#
# Runs a single `llama-server` in router mode (`--models-preset` + `--models-max 1`)
# so multiple models on one host share a single port and LRU-evict before loading
# a second model into VRAM. Idle children sleep after 300s; a companion service
# watching `/models/sse` then unloads them, because sleep leaves the process and
# its swap resident.
{
  config,
  lib,
  pkgs,
  addresses,
  systemdHardening,
  ...
}:
let
  cfg = config.services.llama-cpp-node;
  ai = import ./models.nix { inherit lib; };
  localModels = ai.modelsForHost config.networking.hostName;

  # Explicitly disable the unused GPU backend so hosts with global
  # `nixpkgs.config.rocmSupport = true` (yitaishi) share the cached Vulkan-only
  # derivation rather than compiling both HIP and Vulkan backends.
  package =
    if cfg.backend == "vulkan" then
      pkgs.llama-cpp.override {
        vulkanSupport = true;
        rocmSupport = false;
      }
    else
      pkgs.llama-cpp.override {
        rocmSupport = true;
        vulkanSupport = false;
      };

  presetsFile = pkgs.writeText "llama-cpp-presets.ini" (
    lib.generators.toINIWithGlobalSection { } {
      globalSection = {
        version = 1;
      };
      sections = {
        "*" = {
          device = if cfg.backend == "vulkan" then "Vulkan0" else "ROCm0";
          n-gpu-layers = 99;
          split-mode = "none";
          flash-attn = "on";
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          parallel = 1;
          jinja = true;
          no-mmproj = true;
          dedup-cache-models = true;
          sleep-idle-seconds = 300;
        };
      }
      // lib.mapAttrs (
        _: m:
        {
          hf-repo = "${m.llamaCpp.hfRepo}:${m.llamaCpp.quant}";
          ctx-size = m.contextLength;
          reasoning = if m.reasoning then "on" else "off";
        }
        // lib.optionalAttrs (!m.reasoning) {
          reasoning-format = "none";
        }
        // lib.optionalAttrs ((m.reasoningBudget or null) != null) {
          reasoning-budget = m.reasoningBudget;
        }
      ) localModels;
    }
  );

  tailscaleDeps = lib.optional (
    config.services.tailscale.enable
    && lib.any (addr: addr != "127.0.0.1" && addr != "::1") cfg.listenAddresses
  ) "tailscaled.service";
in
{
  options.services.llama-cpp-node = {
    enable = lib.mkEnableOption "llama.cpp router server from the models.nix registry";

    backend = lib.mkOption {
      type = lib.types.enum [
        "vulkan"
        "rocm"
      ];
      default = "vulkan";
      description = "GPU backend llama.cpp is built with.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses llama-server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = localModels != { };
        message = "services.llama-cpp-node: no models in modules/services/ai/models.nix target ${config.networking.hostName}.";
      }
    ];

    # Registers the RADV ICD under /run/opengl-driver so llama-server finds
    # the Vulkan driver without VK_DRIVER_FILES hacks.
    hardware.graphics.enable = true;

    systemd.services = {
      llama-cpp = {
        description = "llama.cpp router server (${lib.concatStringsSep ", " (lib.attrNames localModels)})";
        after = [ "network-online.target" ] ++ tailscaleDeps;
        wants = [ "network-online.target" ] ++ tailscaleDeps;
        wantedBy = [ "multi-user.target" ];

        # HF cache; also HOME so Mesa/RADV gets a writable shader cache (a
        # DynamicUser's HOME is /, read-only).
        environment = {
          LLAMA_CACHE = "/var/cache/llama-cpp";
          HOME = "/var/cache/llama-cpp";
        };

        postStart = ''
          until ${lib.getExe pkgs.curl} -fso /dev/null http://127.0.0.1:${toString addresses.services.llama-cpp.port}/health; do
            sleep 0.1
          done
        '';

        serviceConfig = removeAttrs systemdHardening [ "PrivateDevices" ] // {
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' package "llama-server")
            "--models-preset ${presetsFile}"
            "--models-max 1"
            "--host ${lib.concatStringsSep "," cfg.listenAddresses}"
            "--port ${toString addresses.services.llama-cpp.port}"
            "--no-ui"
          ];
          CacheDirectory = "llama-cpp";
          DeviceAllow = [ "char-drm rwm" ];
          DynamicUser = true;
          User = "llama-cpp";
          SupplementaryGroups = [
            "video"
            "render"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # Router has no idle unload: sleep-idle-seconds only drops weights inside the
      # child, which stays up (~744 MiB swap observed). Streaming /models/sse
      # unloads the child as soon as it enters sleeping state.
      llama-cpp-idle-unload = {
        description = "Unload llama.cpp models when they enter the idle sleeping state";
        bindsTo = [ "llama-cpp.service" ];
        after = [ "llama-cpp.service" ];
        wantedBy = [ "multi-user.target" ];
        enableStrictShellChecks = true;
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = systemdHardening // {
          DynamicUser = true;
          IPAddressDeny = "any";
          IPAddressAllow = "localhost";
          Restart = "always";
          RestartSec = 2;
        };
        script = ''
          url=http://127.0.0.1:${toString addresses.services.llama-cpp.port}/models
          unload_sleeping() {
            models=$(curl -fsS --max-time 5 "$url")
            jq -c '.data[] | select(.status.value == "sleeping") | {model: .id}' <<< "$models" |
              while IFS= read -r body; do
                curl -fsS --max-time 60 -X POST "$url/unload" -H 'Content-Type: application/json' -d "$body"
              done
          }
          unload_sleeping
          curl -fsSN "$url/sse" |
            while IFS= read -r line; do
              if [[ $line == *'"sleeping"'* ]]; then
                unload_sleeping
              fi
            done
        '';
      };
    };
  };
}
