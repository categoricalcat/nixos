# Declarative local LLM and diffusion model registry.
#
# Sized for Q8_0 KV cache on each host's Vulkan device:
#   - yifuwuqi: Radeon 680M APU (4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM)
#     -> Gemma 4 12B (~6.87 GiB weights, 7381381760 B + ~0.9 GB 64k KV cache via
#        its 8 global-attention layers; 128k fits GTT too, but ~73-107 tok/s UMA
#        prefill makes >64k prompts impractical)
#     -> DeepSeek-V4-Pro-Qwen3.5-9B (~7.04 GiB i1-Q6_K weights, 7558903968 B +
#        ~1.1 GiB 64k KV cache via 8 full-attention + 24 DeltaNet layers)
#   - yitaishi: Radeon RX 7900 XTX (24 GiB GDDR6)
#     -> Qwen 3.8 27B (~16.35 GiB weights, 17559196096 B + ~3.2 GB 96k KV cache
#        via its 16 full-attention layers, 48 DeltaNet layers stay constant;
#        128k would need ~4.3 GB KV and leave <0.5 GiB VRAM next to the measured
#        ~2 GiB idle desktop and sd-cpp's demand cache)
#     -> Gemma 4 26B-A4B MoE (~15.64 GiB weights, 16796015136 B, 3.8B active +
#        ~1.2 GiB 96k KV cache via 5 global + 25 sliding-window layers)
#     -> Chroma1-HD Q8_0 (CPU-backed weights, demand-cached on the GPU while rendering)
{ lib }:
let
  models = {
    "deepseek-v4-pro-qwen3.5-9b-uncensored" = {
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

    "gemma-4-12b-uncensored" = {
      targetHost = "yifuwuqi";
      tools = true;
      # The Heretic template force-prefills the thought channel on every turn,
      # so thinking cannot be disabled; `reasoning = false` only added
      # `reasoning-format=none`, leaking raw thought markers into `content`.
      # Keep reasoning on with unrestricted budget so llama.cpp's gemma4 parser
      # extracts full thoughts into `reasoning_content`.
      reasoning = true;
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "zaakirio/gemma-4-12b-it-uncensored-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma-4-26b-a4b-uncensored" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
      contextLength = 98304;
      llamaCpp = {
        hfRepo = "llmfan46/gemma-4-26B-A4B-it-ultra-uncensored-heretic-GGUF";
        quant = "Q4_K_M";
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

  opencodeModelsForHost =
    host:
    lib.mapAttrs (
      name: m:
      {
        inherit name;
        contextWindow = m.contextLength;
      }
      // lib.optionalAttrs m.tools {
        tools = true;
        tool_call = true;
      }
      // lib.optionalAttrs m.reasoning {
        reasoning = true;
      }
    ) (modelsForHost host);
in
{
  inherit imageModelsForHost modelsForHost opencodeModelsForHost;
}
