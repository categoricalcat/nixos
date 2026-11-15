# Vulkan stable-diffusion.cpp HTTP server (`sd-server`) driven by modules/services/ai/models.nix.
#
# Runs `sd-server` with CPU-backed parameters so GPU replicas are prefetched,
# cached while sampling, and reclaimed afterward. This saturates `Vulkan0`
# during generation without permanently blocking llama.cpp from the GPU.
{
  config,
  lib,
  pkgs,
  addresses,
  systemdHardening,
  ...
}:
let
  cfg = config.services.sd-cpp-node;
  localModels = (import ./models.nix { inherit lib; }).imageModelsForHost config.networking.hostName;
  defaultModel = localModels.${builtins.head (lib.attrNames localModels)};
  cacheDir = "/var/cache/sd-cpp";

  webui = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "sdcpp-webui";
    inherit (pkgs.stable-diffusion-cpp) version;

    src = pkgs.stable-diffusion-cpp.src + "/examples/server/frontend";

    strictDeps = true;

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.pnpm_10
      pkgs.pnpmConfigHook
    ];

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      pnpm = pkgs.pnpm_10;
      fetcherVersion = 4;
      hash = "sha256-CFZUdczhW+kIH+Kyt+3QXMbA2nGoVGXcBcC4LVewaDw=";
    };

    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm444 dist/index.html "$out/index.html"
      runHook postInstall
    '';

    meta = {
      description = "Web interface for stable-diffusion.cpp";
      homepage = "https://github.com/leejet/stable-diffusion.cpp/tree/master/examples/server/frontend";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  });

  tailscaleDeps = lib.optional (
    config.services.tailscale.enable && cfg.listenAddress != "127.0.0.1" && cfg.listenAddress != "::1"
  ) "tailscaled.service";
in
{
  options.services.sd-cpp-node = {
    enable = lib.mkEnableOption "stable-diffusion.cpp server from the models.nix registry";

    backend = lib.mkOption {
      type = lib.types.enum [
        "vulkan"
        "rocm"
      ];
      default = "vulkan";
      description = "GPU backend stable-diffusion.cpp is built with.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address sd-server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = localModels != { };
        message = "services.sd-cpp-node: no imageModels in modules/services/ai/models.nix target ${config.networking.hostName}.";
      }
    ];

    hardware.graphics.enable = true;

    systemd.services = {
      sd-cpp-fetch = {
        description = "Fetch stable-diffusion.cpp model weights (${lib.concatStringsSep ", " (lib.attrNames localModels)})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.OnSuccess = [ "sd-cpp.service" ];
        enableStrictShellChecks = true;

        path = [
          pkgs.coreutils
          pkgs.curl
        ];

        script = lib.concatLines (
          lib.attrValues (
            lib.mapAttrs (
              _: f:
              let
                target = "${cacheDir}/${f.file}";
                partial = "${target}.part";
              in
              ''
                if ! printf '%s  %s\n' ${lib.escapeShellArg f.sha256} ${lib.escapeShellArg target} | sha256sum --check --status 2>/dev/null; then
                  if [ -f ${lib.escapeShellArg target} ]; then
                    rm -f ${lib.escapeShellArg partial}
                  fi
                  curl --fail --silent --show-error --location --continue-at - \
                    --output ${lib.escapeShellArg partial} \
                    ${lib.escapeShellArg "https://huggingface.co/${f.hfRepo}/resolve/main/${f.file}"}
                  if ! printf '%s  %s\n' ${lib.escapeShellArg f.sha256} ${lib.escapeShellArg partial} | sha256sum -c -; then
                    rm -f ${lib.escapeShellArg partial}
                    exit 1
                  fi
                  mv ${lib.escapeShellArg partial} ${lib.escapeShellArg target}
                fi
              ''
            ) defaultModel.files
          )
        );

        serviceConfig = systemdHardening // {
          CacheDirectory = "sd-cpp";
          DynamicUser = true;
          User = "sd-cpp";
          Type = "simple";
          RuntimeMaxSec = "6h";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };

      sd-cpp = {
        description = "stable-diffusion.cpp server (${lib.concatStringsSep ", " (lib.attrNames localModels)})";
        after = [ "network-online.target" ] ++ tailscaleDeps;
        wants = [ "network-online.target" ] ++ tailscaleDeps;
        enableStrictShellChecks = true;

        path = [
          pkgs.coreutils
          pkgs.curl
        ];

        # Writable HOME for Mesa/RADV Vulkan shader cache under DynamicUser.
        environment.HOME = cacheDir;

        postStart = ''
          until curl -fso /dev/null http://127.0.0.1:${toString addresses.services.sd-cpp.port}/v1/models; do
            sleep 0.2
          done
        '';

        serviceConfig = removeAttrs systemdHardening [ "PrivateDevices" ] // {
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' (
              if cfg.backend == "vulkan" then
                pkgs.stable-diffusion-cpp.override {
                  vulkanSupport = true;
                  rocmSupport = false;
                }
              else
                pkgs.stable-diffusion-cpp.override {
                  rocmSupport = true;
                  vulkanSupport = false;
                }
            ) "sd-server")
            "--listen-ip ${cfg.listenAddress}"
            "--listen-port ${toString addresses.services.sd-cpp.port}"
            "--serve-html-path ${webui}/index.html"
            "--backend ${if cfg.backend == "vulkan" then "vulkan0" else "rocm0"}"
            "--offload-to-cpu"
            "--flash-attn on"
            "--vae-tiling"
            "--diffusion-model ${cacheDir}/${defaultModel.files.diffusionModel.file}"
            "--t5xxl ${cacheDir}/${defaultModel.files.t5xxl.file}"
            "--vae ${cacheDir}/${defaultModel.files.vae.file}"
            "-W ${toString defaultModel.width}"
            "-H ${toString defaultModel.height}"
            "--steps ${toString defaultModel.steps}"
            "--cfg-scale ${defaultModel.cfgScale}"
            "--sampling-method ${defaultModel.samplingMethod}"
          ];
          CacheDirectory = "sd-cpp";
          DeviceAllow = [ "char-drm rwm" ];
          DynamicUser = true;
          User = "sd-cpp";
          SupplementaryGroups = [
            "video"
            "render"
          ];
          TimeoutStartSec = "15min";
          IPAddressDeny = "any";
          IPAddressAllow = [
            "localhost"
            "100.64.0.0/10"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
}
