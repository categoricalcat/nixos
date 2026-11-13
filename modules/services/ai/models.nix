# Declarative local LLM registry (2 models per host: censored + uncensored).
#
# Sized for Q8_0 KV cache on each host's Vulkan device:
#   - yifuwuqi: Radeon 680M APU (4 GiB carved VRAM + 9.65 GiB GTT out of 19.3 GiB RAM)
#     -> Gemma 4 12B (~7 GB weights + <0.5 GB 32k KV cache via 8 global-attention layers)
#   - yitaishi: Radeon RX 7900 XTX (24 GiB GDDR6)
#     -> Qwen 3.8 27B (~16.4-17.7 GB weights + ~2.4 GB 64k hybrid DeltaNet KV cache)
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
  inherit modelsForHost opencodeModelsForHost;
}
