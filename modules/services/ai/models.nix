# Declarative local LLM and diffusion model registry.
#
# Sized for Q8_0 KV cache on each host's Vulkan device:
#   - yifuwuqi: Radeon 680M APU (4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM)
#     -> Gemma 4 12B (~6.8 GB weights, 7350597824 B measured + ~0.9 GB 64k KV cache
#        via its 8 global-attention layers; 128k fits GTT too, but ~73-107 tok/s
#        UMA prefill makes >64k prompts impractical)
#   - yitaishi: Radeon RX 7900 XTX (24 GiB GDDR6)
#     -> Qwen 3.8 27B (~16.3 GB weights, 17548181504 B measured + ~3.2 GB 96k KV
#        cache via its 16 full-attention layers, 48 DeltaNet layers stay constant;
#        128k would need ~4.3 GB KV and leave <0.5 GiB VRAM next to the measured
#        ~2 GiB idle desktop and sd-cpp's demand cache)
#     -> Chroma1-HD Q8_0 (CPU-backed weights, demand-cached on the GPU while rendering)
{ lib }:
let
  models = {
    "gemma-4-12b" = {
      targetHost = "yifuwuqi";
      tools = true;
      reasoning = true;
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "unsloth/gemma-4-12b-it-GGUF";
        quant = "UD-Q4_K_XL";
      };
    };

    "gemma-4-12b-uncensored" = {
      targetHost = "yifuwuqi";
      tools = true;
      # The Heretic template force-prefills the thought channel on every turn,
      # so thinking cannot be disabled; `reasoning = false` only added
      # `reasoning-format=none`, leaking raw thought markers into `content`.
      # Keep reasoning on so llama.cpp's gemma4 parser extracts thoughts into
      # `reasoning_content` (SillyTavern can collapse/hide them).
      reasoning = true;
      # Cap thinking tokens so SillyTavern's 2048 max_tokens budget leaves room for the reply.
      reasoningBudget = 512;
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "zaakirio/gemma-4-12b-it-uncensored-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.8-27b" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
      contextLength = 98304;
      llamaCpp = {
        hfRepo = "unsloth/Qwen3.8-27B-GGUF";
        quant = "UD-Q4_K_XL";
      };
    };

    "qwen3.8-27b-uncensored" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
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
