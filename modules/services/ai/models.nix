# Declarative local LLM and diffusion model registry.
#
# Sized for Q8_0 KV cache (34/32 B/elem) on each host's Vulkan device:
#   - yifuwuqi: Radeon 680M APU (4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM)
#     -> Mag Mell 12B (~6.96 GiB i1-Q4_K_M weights, 7477206400 B + ~2.66 GiB 32k
#        KV cache via its 40 full-attention layers; 64k KV would take ~5.31 GiB
#        and squeeze both the 13.65 GiB GPU cap and the 19.3 GiB shared host RAM)
#     -> DeepSeek-V4-Pro-Qwen3.5-9B (~7.04 GiB i1-Q6_K weights, 7558903968 B +
#        ~1.1 GiB 64k KV cache via 8 full-attention + 24 DeltaNet layers)
#   - yitaishi: Radeon RX 7900 XTX (24 GiB GDDR6)
#     -> Qwen 3.8 27B (~16.35 GiB weights, 17559196096 B + ~3.2 GB 96k KV cache
#        via its 16 full-attention layers, 48 DeltaNet layers stay constant;
#        128k would need ~4.3 GB KV and leave <0.5 GiB VRAM next to the measured
#        ~2 GiB idle desktop and sd-cpp's demand cache)
#     -> Cydonia 24B (~13.35 GiB i1-Q4_K_M weights, 14333911360 B + ~5.31 GiB
#        64k KV cache via its 40 full-attention layers; 96k KV would take
#        ~7.97 GiB and exceed 24 GiB VRAM once compute buffers and the ~2 GiB
#        idle desktop are counted)
#     -> Chroma1-HD Q8_0 (CPU-backed weights, demand-cached on the GPU while rendering)
{ lib }:
let
  defaultModelIds = {
    opencodeResearch = "deepseek-v4-pro-qwen3.5-9b-uncensored";
    sillytavern = "mag-mell-12b-uncensored";
  };

  models = {
    ${defaultModelIds.opencodeResearch} = {
      targetHost = "yifuwuqi";
      tools = true;
      reasoning = true;
      contextLength = 65536;
      llamaCpp = {
        # xtools-at Heretic v2.0 ARA (3/100 refusals, 0.0422 KL) over Jackrong's
        # DeepSeek-V4-Pro distillation into Qwen3.5-9B; imatrix Q6_K quant.
        hfRepo = "mradermacher/DeepSeek-V4-Pro-Qwen3.5-9B-UNCENSORED-heretic-i1-GGUF";
        quant = "i1-Q6_K";
      };
    };

    ${defaultModelIds.sillytavern} = {
      targetHost = "yifuwuqi";
      # Plain ChatML RP merge with neither tool-call syntax nor thought channel;
      # keep both off so OpenCode never emits tool calls or expects
      # `reasoning_content`, and llama.cpp sets `reasoning-format=none`.
      tools = false;
      reasoning = false;
      contextLength = 32768;
      llamaCpp = {
        # Multi-stage merge of Mistral-Nemo RP/prose tunes (R1 revision); imatrix Q4_K_M quant.
        hfRepo = "mradermacher/MN-12B-Mag-Mell-R1-i1-GGUF";
        quant = "i1-Q4_K_M";
      };
    };

    "cydonia-24b-uncensored" = {
      targetHost = "yitaishi";
      # Mistral-Small-3.2 RP tune; GGUF template supports user/system/assistant
      # only (raises on `tool` role) and has no thought channel.
      tools = false;
      reasoning = false;
      contextLength = 65536;
      llamaCpp = {
        # Heretic v1.2.0 MPOA abliteration (14/100 refusals, 0.0069 KL) over Cydonia
        # v4.3, a Mistral-Small-3.2-24B RP tune; imatrix Q4_K_M quant.
        hfRepo = "mradermacher/Cydonia-24B-v4.3-heretic-v4-i1-GGUF";
        quant = "i1-Q4_K_M";
      };
    };

    "qwen3.8-27b-uncensored" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
      # qwen3.8-safe-v3.1 rejects `max` and maps `high`/`xhigh` to its deepest reasoning level.
      reasoningEffort = "xhigh";
      contextLength = 98304;
      llamaCpp = {
        hfRepo = "ajgazin/Qwen3.8-27B-Heretic-Dynamic-GGUF";
        quant = "UD-Q4_K_XL";
      };
    };
  };

  defaultModels = lib.mapAttrs (_: name: models.${name} // { inherit name; }) defaultModelIds;

  modelsForHost = host: lib.filterAttrs (_: m: m.targetHost == host) models;

  imageModelsForHost =
    host:
    lib.filterAttrs (_: m: m.targetHost == host) {
      "chroma1-hd" = {
        targetHost = "yitaishi";
        width = 1024;
        height = 1024;
        steps = 20;
        cfgScale = "3.5";
        samplingMethod = "euler";
        files = {
          diffusionModel = {
            hfRepo = "silveroxides/Chroma1-HD-GGUF";
            file = "Chroma1-HD-Q8_0.gguf";
            sha256 = "8c8d66177bfc584573dd21584399ebc1f00bde60acbbc48ac3cc8f58f10c6094";
          };
          t5xxl = {
            hfRepo = "city96/t5-v1_1-xxl-encoder-gguf";
            file = "t5-v1_1-xxl-encoder-Q8_0.gguf";
            sha256 = "9ec60f6028534b7fe5af439fcb535d75a68592a9ca3fcdeb175ef89e3ee99825";
          };
          vae = {
            hfRepo = "lodestones/Chroma";
            file = "ae.safetensors";
            sha256 = "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38";
          };
        };
      };
    };

  # OpenCode 2 model shape: `limit` bounds the request, `capabilities` decides
  # which tool calls the client may emit. Every local build runs --no-mmproj,
  # so input is text only; llama-server takes `max_tokens` and answers with
  # `reasoning_content` only for reasoning-enabled models (setting
  # `reasoningField` unconditionally implies `requireReasoning` in OpenCode 2).
  # llama-server sets no n_predict ceiling. OpenCode fits `max_tokens` to the
  # room left in the window, then clamps it to `output`, and compaction packs
  # the transcript up to that same clamp. Below its 16k reserve the summary is
  # left too little room and a length finish fails the session, so reasoning
  # models use OpenCode's own 32k ceiling.
  opencodeModelsForHost =
    host:
    lib.mapAttrs (_: m: {
      limit = {
        context = m.contextLength;
        output = if m.reasoning then 32768 else 8192;
      };
      compatibility = {
        maxTokensField = "max_tokens";
      }
      // lib.optionalAttrs m.reasoning {
        reasoningField = "reasoning_content";
      };
      capabilities = {
        inherit (m) tools;
        input = [ "text" ];
        output = [ "text" ];
      }
      // lib.optionalAttrs m.reasoning {
        reasoning.supported = true;
      };
    }) (modelsForHost host);
in
{
  inherit
    defaultModels
    imageModelsForHost
    modelsForHost
    opencodeModelsForHost
    ;
}
