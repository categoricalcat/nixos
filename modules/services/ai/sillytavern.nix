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
  stateDir = "/var/lib/SillyTavern";
  dataDir = "${stateDir}/data";
  userDataDir = "${dataDir}/${cfg.userHandle}";
  presetsDir = "${userDataDir}/OpenAI Settings";

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

  modelPresets = {
    "mag-mell-12b-uncensored" = {
      # Plain ChatML RP merge: author recommends Temp 1.25 + MinP 0.2 without XTC/penalties;
      # keep DRY gentle across long RP turns and remove top_k/top_p clipping.
      temperature = 1.25;
      topP = 1.0;
      topK = 0;
      minP = 0.2;
      presencePenalty = 0.0;
      promptPostProcessing = "merge";
      reasoningTemplate = "Blank";
      dry = {
        multiplier = 0.5;
        base = 1.75;
        allowedLength = 3;
        penaltyLastN = 2048;
      };
    };
    "cydonia-24b-uncensored" = {
      # Mistral V7 Tekken RP baseline: Temp 0.85 + MinP 0.05 + DRY, with
      # top_k/top_p clipping disabled.
      temperature = 0.85;
      topP = 1.0;
      topK = 0;
      minP = 0.05;
      presencePenalty = 0.0;
      promptPostProcessing = "merge";
      reasoningTemplate = "Blank";
      dry = {
        multiplier = 0.8;
        base = 1.75;
        allowedLength = 2;
        penaltyLastN = 2048;
      };
    };
    "deepseek-v4-pro-qwen3.5-9b-uncensored" = {
      # Qwen3.5 distillation: use its recommended thinking samplers and normalize
      # unsupported non-leading system roles with `semi_tools`.
      temperature = 1.0;
      topP = 0.95;
      topK = 20;
      minP = 0.0;
      presencePenalty = 1.5;
      promptPostProcessing = "semi_tools";
      reasoningTemplate = "Think XML";
    };
    "qwen3.8-27b-uncensored" = {
      # Official thinking-mode samplers; its template throws on non-leading
      # system roles, so normalize them with `semi_tools`.
      temperature = 1.0;
      topP = 0.95;
      topK = 20;
      minP = 0.0;
      presencePenalty = 0.0;
      promptPostProcessing = "semi_tools";
      reasoningTemplate = "Think XML";
    };
  };

  hostedModels = entriesForService "llama-cpp" (
    hostName: endpoint:
    lib.mapAttrsToList (model: modelCfg: {
      inherit
        hostName
        endpoint
        model
        modelCfg
        ;
    }) (ai.modelsForHost hostName)
  );

  specFor =
    model:
    assert lib.assertMsg (
      modelPresets ? ${model}
    ) "yi.services.sillytavern: model '${model}' has no SillyTavern preset.";
    modelPresets.${model};
  presetNameFor = model: "Nix - ${model}";
  maxTokensFor = modelCfg: if modelCfg.reasoning then 16384 else 4096;

  configuredModels = map (
    entry:
    entry
    // {
      spec = specFor entry.model;
      presetName = presetNameFor entry.model;
    }
  ) hostedModels;

  # SillyTavern's `custom` Chat Completions backend omits top_k, min_p, repeat_penalty,
  # and DRY from its OpenAI body and merges custom_include_body last.
  formatCustomIncludeBody =
    spec:
    lib.concatStringsSep "\n" (
      [
        "top_k: ${builtins.toJSON spec.topK}"
        "min_p: ${builtins.toJSON spec.minP}"
        "repeat_penalty: 1"
      ]
      ++ lib.optionals (spec ? dry) [
        "dry_multiplier: ${builtins.toJSON spec.dry.multiplier}"
        "dry_base: ${builtins.toJSON spec.dry.base}"
        "dry_allowed_length: ${builtins.toJSON spec.dry.allowedLength}"
        "dry_penalty_last_n: ${builtins.toJSON spec.dry.penaltyLastN}"
      ]
    );

  mkSharedOaiConfig =
    modelCfg: spec:
    {
      max_context_unlocked = true;
      openai_max_tokens = maxTokensFor modelCfg;
      stream_openai = true;
      show_thoughts = modelCfg.reasoning;
      custom_include_body = formatCustomIncludeBody spec;
      custom_prompt_post_processing = spec.promptPostProcessing;
      media_inlining = false;
    }
    // lib.optionalAttrs (modelCfg ? reasoningEffort) {
      reasoning_effort = modelCfg.reasoningEffort;
    };

  mkOaiSettings =
    model: modelCfg: spec:
    (mkSharedOaiConfig modelCfg spec)
    // {
      preset_settings_openai = presetNameFor model;
      temp_openai = spec.temperature;
      top_p_openai = spec.topP;
      top_k_openai = spec.topK;
      min_p_openai = spec.minP;
      top_a_openai = 0.0;
      freq_pen_openai = 0.0;
      pres_pen_openai = spec.presencePenalty;
      repetition_penalty_openai = 1.0;
      bind_preset_to_connection = true;
    };

  mkOaiPreset =
    modelCfg: spec:
    (mkSharedOaiConfig modelCfg spec)
    // {
      openai_max_context = modelCfg.contextLength;
      inherit (spec) temperature;
      top_p = spec.topP;
      top_k = spec.topK;
      min_p = spec.minP;
      top_a = 0.0;
      frequency_penalty = 0.0;
      presence_penalty = spec.presencePenalty;
      repetition_penalty = 1.0;
    };

  profiles = map (entry: {
    id = "nix:${entry.hostName}:${entry.model}";
    mode = "cc";
    name = "${entry.hostName} / ${entry.model}";
    api = "custom";
    "api-url" = "${entry.endpoint}/v1";
    inherit (entry) model;
    preset = entry.presetName;
    "prompt-post-processing" = entry.spec.promptPostProcessing;
    "reasoning-template" = entry.spec.reasoningTemplate;
    # Transient Nix metadata stripped by overlayScript before writing settings.json.
    inherit (entry.modelCfg) contextLength;
    oaiSettings = mkOaiSettings entry.model entry.modelCfg entry.spec;
    reasoningSettings = reasoningTemplateData.${entry.spec.reasoningTemplate};
    exclude = [ ];
  }) configuredModels;

  presetFiles = map (entry: {
    name = entry.presetName;
    file = jsonFormat.generate "sillytavern-oai-preset-${entry.model}.json" (
      mkOaiPreset entry.modelCfg entry.spec
    );
  }) configuredModels;

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
  defaultSpec = specFor defaultModel.name;

  reasoningTemplateData = {
    Blank = {
      name = "Blank";
      prefix = "";
      suffix = "";
      separator = "";
    };
    "Think XML" = {
      name = "Think XML";
      prefix = "<think>";
      suffix = "</think>";
      separator = "\n";
    };
  };

  overlayScript = pkgs.writeShellApplication {
    name = "sillytavern-settings-overlay";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./sillytavern-settings-overlay.sh;
  };

  # Bundled Noto Sans has no CJK, so Chinese falls back to another face.
  # These four files are the text faces in maple-mono.NF-CN-unhinted.
  mapleMono = (import ../../theme-assets.nix { inherit pkgs; }).fonts.mapleMono;
  themeFontCss = pkgs.writeText "sillytavern-theme-font.css" (
    ''
      /* nix-theme-font:start */
    ''
    +
      lib.concatMapStrings
        (face: ''
          @font-face {
            font-family: "${mapleMono.name}";
            font-style: ${face.style};
            font-weight: ${toString face.weight};
            font-display: swap;
            src: local("${mapleMono.name} ${face.local}"), url("/theme-fonts/${face.file}") format("truetype");
          }
        '')
        [
          {
            weight = 400;
            style = "normal";
            local = "Regular";
            file = "MapleMono-NF-CN-Regular.ttf";
          }
          {
            weight = 400;
            style = "italic";
            local = "Italic";
            file = "MapleMono-NF-CN-Italic.ttf";
          }
          {
            weight = 700;
            style = "normal";
            local = "Bold";
            file = "MapleMono-NF-CN-Bold.ttf";
          }
          {
            weight = 700;
            style = "italic";
            local = "Bold Italic";
            file = "MapleMono-NF-CN-BoldItalic.ttf";
          }
        ]
    + ''
      :root {
        --mainFontFamily: "${mapleMono.name}", "Noto Sans", sans-serif;
        --monoFontFamily: "${mapleMono.name}", "Noto Sans Mono", ui-monospace, monospace;
      }
      /* nix-theme-font:end */
    ''
  );
  themeFontScript = pkgs.writeShellApplication {
    name = "sillytavern-theme-font";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = builtins.readFile ./sillytavern-theme-font.sh;
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

    themeFont = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      internal = true;
      readOnly = true;
      default = {
        package = themeFontScript;
        file = themeFontCss;
      };
      description = "user.css theme-font splice and the CSS block it installs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (
          entry: maxTokensFor entry.modelCfg < entry.modelCfg.contextLength
        ) hostedModels;
        message = "yi.services.sillytavern: every model context must exceed its SillyTavern output-token cap.";
      }
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
        dataRoot = dataDir;
        listen = false;
        browserLaunch.enabled = false;
        whitelistMode = false;
        enableUserAccounts = false;
        basicAuthMode = false;
        hostWhitelist = {
          enabled = true;
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
        seedPowerUser = {
          auto_fix_generated_markdown = true;
          reasoning = reasoningTemplateData.${defaultSpec.reasoningTemplate} // {
            auto_parse = true;
          };
        };
        oai_settings = (mkOaiSettings defaultModel.name defaultModel defaultSpec) // {
          chat_completion_source = "custom";
          custom_url = if defaultProfile != null then defaultProfile."api-url" else "";
          custom_model = defaultModel.name;
          openai_max_context = if defaultProfile != null then defaultProfile.contextLength else 4095;
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
        themeFontCss
      ];

      environment = {
        HOME = stateDir;
        XDG_DATA_HOME = "/var/lib";
      };

      preStart = ''
        install -d -m 0700 ${lib.escapeShellArg dataDir}
        chmod 0700 ${
          lib.escapeShellArgs [
            stateDir
            dataDir
          ]
        }

        # Copy rather than symlink config.yaml so startup default backfills and
        # atomic writes succeed under 0600 ownership.
        rm -f ${lib.escapeShellArg "${stateDir}/config.yaml"}
        install -m 0600 "${configYaml}" ${lib.escapeShellArg "${stateDir}/config.yaml"}

        presets_dir=${lib.escapeShellArg presetsDir}
        install -d -m 0700 "$presets_dir"
        rm -f -- "$presets_dir"/Nix\ -\ *.json
        ${lib.concatStringsSep "\n" (
          map (
            preset:
            "install -m 0600 ${lib.escapeShellArg "${preset.file}"} ${lib.escapeShellArg "${presetsDir}/${preset.name}.json"}"
          ) presetFiles
        )}

        ${lib.escapeShellArg (lib.getExe overlayScript)} \
          ${lib.escapeShellArg "${userDataDir}/settings.json"} \
          ${lib.escapeShellArg "${stRoot}/default/content/settings.json"} \
          "${nixOverlayJson}"

        ${lib.escapeShellArg (lib.getExe themeFontScript)} \
          ${lib.escapeShellArg "${dataDir}/_css/user.css"} \
          ${themeFontCss}

        chmod -R go= ${lib.escapeShellArg dataDir}
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
        WorkingDirectory = stateDir;

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

    # Same peer allow as the local-ingress proxy location: only yirukou
    # reaches this vhost. local() skips the download when the face is installed.
    services.nginx.virtualHosts.${yifuwuqiSt.domain}.locations."/theme-fonts/" = {
      alias = "${mapleMono.package}/share/fonts/truetype/";
      extraConfig = ''
        allow ${allAddresses.hosts.yirukou.network.lan.ipv4.host};
        deny all;
      '';
    };
  };
}
