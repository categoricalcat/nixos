{
  config,
  lib,
  pkgs,
  allAddresses,
  systemdHardening,
  ...
}:

let
  ai = import ./models.nix { inherit lib; };
  yamlFormat = pkgs.formats.yaml { };
  jsonFormat = pkgs.formats.json { };

  cfg = config.yi.services.sillytavern;
  stRoot = "${pkgs.sillytavern}/lib/node_modules/sillytavern";
  yifuwuqiSt = allAddresses.hosts.yifuwuqi.services.sillytavern;

  entriesForService =
    service: mkHostEntries:
    lib.pipe allAddresses.hosts [
      (lib.filterAttrs (_: h: (h.services or { }) ? ${service}))
      (lib.mapAttrsToList (
        hostName: hostCfg:
        let
          host =
            if hostName == config.networking.hostName then "127.0.0.1" else hostCfg.network.vpn.ipv4.host;
          endpoint = "http://${host}:${toString hostCfg.services.${service}.port}";
        in
        mkHostEntries hostName endpoint
      ))
      lib.concatLists
    ];

  profiles = entriesForService "llama-cpp" (
    hostName: endpoint:
    lib.mapAttrsToList (model: modelCfg: {
      id = "nix:${hostName}:${model}";
      mode = "cc";
      name = "${hostName} / ${model}";
      api = "custom";
      "api-url" = "${endpoint}/v1";
      inherit model;
      inherit (modelCfg) contextLength;
      exclude = [ ];
    }) (ai.modelsForHost hostName)
  );

  sdEntries = entriesForService "sd-cpp" (
    hostName: endpoint:
    lib.mapAttrsToList (model: imageCfg: {
      source = "sdcpp";
      sdcpp_url = endpoint;
      inherit model;
      inherit (imageCfg) width height steps;
      scale = builtins.fromJSON imageCfg.cfgScale;
      sampler = imageCfg.samplingMethod;
      refine_mode = true;
    }) (ai.imageModelsForHost hostName)
  );

  defaultModel = ai.defaultModels.sillytavern;
  defaultProfileId = "nix:${defaultModel.targetHost}:${defaultModel.name}";
  defaultProfile = lib.findFirst (p: p.id == defaultProfileId) null profiles;

  overlayScript = pkgs.writeShellApplication {
    name = "sillytavern-settings-overlay";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./sillytavern-settings-overlay.sh;
  };

  configYaml = yamlFormat.generate "sillytavern-config.yaml" cfg.config;
  nixOverlayJson = jsonFormat.generate "sillytavern-nix-overlay.json" cfg.settings;
in
{
  options.yi.services.sillytavern = {
    enable = lib.mkEnableOption "SillyTavern local AI companion";

    userHandle = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "default-user";
      description = "SillyTavern user data directory handle under dataRoot.";
    };

    config = lib.mkOption {
      inherit (yamlFormat) type;
      default = { };
      description = "Declarative SillyTavern config.yaml overrides (missing upstream defaults are populated by SillyTavern on startup).";
    };

    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      description = "Declarative Nix-owned subset overlaid into SillyTavern settings.json (do not set list-valued mutable keys such as oai_settings.prompts or prompt_order, as jq * replaces arrays wholesale).";
    };

    settingsOverlay = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      internal = true;
      readOnly = true;
      default = {
        package = overlayScript;
        file = nixOverlayJson;
      };
      description = "Evaluated settings.json overlay package and JSON payload shared with flake checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = defaultProfile != null;
        message = "yi.services.sillytavern: default profile '${defaultProfileId}' missing from models.nix + allAddresses.";
      }
      {
        assertion = lib.length sdEntries == 1;
        message = "yi.services.sillytavern: expected exactly 1 sd-cpp image model in models.nix + allAddresses, found ${toString (lib.length sdEntries)}.";
      }
      {
        assertion = !(cfg.config.basicAuthMode or false) || (cfg.config.listen or false);
        message = "yi.services.sillytavern: config.basicAuthMode = true requires config.listen = true (otherwise SillyTavern does not attach basicAuthMiddleware).";
      }
      {
        assertion =
          !(cfg.settings.oai_settings or { } ? prompts) && !(cfg.settings.oai_settings or { } ? prompt_order);
        message = "yi.services.sillytavern: settings.oai_settings must not define prompts or prompt_order (mutable arrays overwritten by jq *).";
      }
    ];

    yi.services.sillytavern = {
      config = lib.mapAttrsRecursive (_: lib.mkDefault) {
        inherit (yifuwuqiSt) port;
        dataRoot = "/var/lib/SillyTavern/data";
        listen = false;
        whitelistMode = false;
        enableUserAccounts = false;
        basicAuthMode = false;
        hostWhitelist = {
          enabled = false;
          scan = false;
          hosts = [ yifuwuqiSt.domain ];
        };
        logging.minLogLevel = 1;
        extensions = {
          enabled = true;
          autoUpdate = false;
        };
      };

      settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
        main_api = "openai";
        oai_settings = {
          chat_completion_source = "custom";
          custom_url = if defaultProfile != null then defaultProfile."api-url" else "";
          custom_model = defaultModel.name;
          openai_max_context = if defaultProfile != null then defaultProfile.contextLength else 4095;
          max_context_unlocked = true;
          openai_max_tokens = 4096;
          stream_openai = true;
          temp_openai = 1.0;
          top_p_openai = 0.95;
          show_thoughts = true;
          reasoning_effort = "max";
          verbosity = "low";
          # SillyTavern's custom backend drops reasoning_effort for non-OpenAI
          # model names; Qwen 3.8 rejects `max` and accepts `xhigh` cleanly.
          custom_include_body = "reasoning_effort: xhigh";
          # Consolidate leading system prompts and turn mid-chat system injects
          # into user messages (Qwen 3.8 errors on non-leading system roles).
          custom_prompt_post_processing = "semi_tools";
          media_inlining = false;
        };
        extension_settings =
          lib.optionalAttrs (sdEntries != [ ]) {
            sd = lib.head sdEntries;
          }
          // {
            connectionManager = {
              inherit profiles;
              selectedProfile = defaultProfileId;
            };
          };
      };
    };

    users.users.sillytavern = {
      isSystemUser = true;
      group = "sillytavern";
    };
    users.groups.sillytavern = { };

    systemd.services.sillytavern = {
      description = "Silly Tavern";
      after = [
        "network.target"
        "llama-cpp.service"
      ];
      wants = [ "llama-cpp.service" ];
      wantedBy = [ "multi-user.target" ];

      restartTriggers = [
        configYaml
        nixOverlayJson
      ];

      environment = {
        HOME = "/var/lib/SillyTavern";
        XDG_DATA_HOME = "/var/lib";
      };

      preStart = ''
        install -d -m 0700 /var/lib/SillyTavern/data
        chmod 0700 /var/lib/SillyTavern /var/lib/SillyTavern/data
        chmod -R go= /var/lib/SillyTavern/data

        # Copy rather than symlink config.yaml so startup default backfills and
        # atomic writes succeed under 0600 ownership.
        rm -f /var/lib/SillyTavern/config.yaml
        install -m 0600 "${configYaml}" /var/lib/SillyTavern/config.yaml

        ${lib.escapeShellArg (lib.getExe overlayScript)} \
          ${lib.escapeShellArg "/var/lib/SillyTavern/data/${cfg.userHandle}/settings.json"} \
          ${lib.escapeShellArg "${stRoot}/default/content/settings.json"} \
          "${nixOverlayJson}"
      '';

      serviceConfig = {
        # Client-facing hosted service (sillytavern.aset.love) behind the local
        # ingress: loopback-only (listen = false in config.yaml) and
        # whitelistMode = false so LAN clients forwarded through nginx pass.
        ExecStart = lib.getExe' pkgs.sillytavern "sillytavern";
        User = "sillytavern";
        Group = "sillytavern";
        StateDirectory = "SillyTavern";
        StateDirectoryMode = "0700";
        UMask = "0077";
        WorkingDirectory = "/var/lib/SillyTavern";

        Restart = "always";
        Type = "simple";
      }
      # Node.js JIT needs writable executable mappings, and its fs layer
      # chowns (@chown sits outside @system-service; same exception as the
      # Arr apps in servarrHardening).
      // removeAttrs systemdHardening [ "MemoryDenyWriteExecute" ]
      // {
        SystemCallFilter = lib.splitString " " "@system-service ~@privileged @chown";
      };
    };
  };
}
