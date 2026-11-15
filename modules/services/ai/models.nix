# Declarative local LLM and diffusion model registry.
#
# Sized for Q8_0 KV cache on each host's Vulkan device:
#   - yifuwuqi: Radeon 680M APU (4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM)
#     -> Gemma 4 12B (~7 GB weights + <0.5 GB 32k KV cache via 8 global-attention layers)
#   - yitaishi: Radeon RX 7900 XTX (24 GiB GDDR6)
#     -> Qwen 3.8 27B (~16.4-17.7 GB weights + ~2.4 GB 64k hybrid DeltaNet KV cache)
#     -> Chroma1-HD Q8_0 (CPU-backed weights, demand-cached on the GPU while rendering)
{ lib }:
let
  models = {
    "gemma-4-12b" = {
      targetHost = "yifuwuqi";
      tools = true;
      reasoning = true;
      contextLength = 32768;
      llamaCpp = {
        hfRepo = "unsloth/gemma-4-12b-it-GGUF";
        quant = "UD-Q4_K_XL";
      };
    };

    "gemma-4-12b-uncensored" = {
      targetHost = "yifuwuqi";
      tools = true;
      # Gemma 4 Heretic abliteration targets direct responses; keeping thinking
      # off avoids CoT consuming SillyTavern's generation budget.
      reasoning = false;
      contextLength = 32768;
      llamaCpp = {
        hfRepo = "zaakirio/gemma-4-12b-it-uncensored-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.8-27b" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "unsloth/Qwen3.8-27B-GGUF";
        quant = "UD-Q4_K_XL";
      };
    };

    "qwen3.8-27b-uncensored" = {
      targetHost = "yitaishi";
      tools = true;
      reasoning = true;
      contextLength = 65536;
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
