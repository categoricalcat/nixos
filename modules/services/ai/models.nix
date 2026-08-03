# Provider-agnostic model registry. Each entry declares capabilities
# (`tools`, `reasoning`, `contextLength`, `yarn`) and a llama.cpp source
# (`llamaCpp.hfRepo` + `quant`) that llama-cpp.nix pulls from HuggingFace on
# first start. All consumers derive their own schema from this single map.
#
# Imported as plain data (no module args) so it works from both NixOS modules
# and home-manager modules.
#
# Consumed by:
#   - modules/services/ai/llama-cpp.nix -> per-model llama-server units
#   - users/programs/opencode.nix       -> provider.local/yitaishi.models
#
# An entry is served by a llama-cpp-node unit iff it is enabled, targets the
# local host (`targetHost`) and declares a `port`. Enabled entries without a
# local unit are expected to be reachable on their targetHost (the router
# forwards those by model name).
#
# Context-length policy:
#   Per-model `contextLength` reflects what fits in the target GPU's VRAM
#   *with Q8 KV cache* (which llama-cpp.nix sets per unit). Models run
#   either on yitaishi's RX 7900 XTX (24 GiB) or yifuwuqi's Radeon 680M
#   (~9.6 GiB UMA budget).
#
# YaRN policy:
#   `yarn` is set ONLY for models whose target context exceeds their native
#   training window. For Qwen models that means scaling their 32k native
#   limit up to 64k or 128k. Models with native >= target (gpt-oss 128k,
#   qwen3-coder 256k, gemma3/granite4/dr1-llama-base 128k) DO NOT use YaRN
#   because YaRN slightly degrades short-context perf for no upside when
#   the native window already covers the target.
let
  filterAttrs =
    p: s:
    builtins.listToAttrs (
      builtins.concatMap (
        n:
        if p n s.${n} then
          [
            {
              name = n;
              value = s.${n};
            }
          ]
        else
          [ ]
      ) (builtins.attrNames s)
    );

  allModels = {
    # -------------------------------------------------------------------------
    # Qwen Family (Alibaba)
    # -------------------------------------------------------------------------
    "qwen2.5:7b" = {
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      # llama-server unit on yifuwuqi (Vulkan). 32k native window; the old
      # 4096 cap was an Ollama-ROCm artifact, not a hardware limit.
      contextLength = 32768;
      llamaCpp = {
        hfRepo = "bartowski/Qwen2.5-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.6-35b-a3b" = {
      enable = true;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      port = 11436;
      contextLength = 16384; # maybe start at 16384, watch RAM
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3.6-35B-A3B-GGUF";
        quant = "IQ2_M"; # 12.96 GB — safe with KV cache + OS
      };
    };

    "qwen3.6-35b-abliterated" = {
      enable = true;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      port = 11437;
      contextLength = 16384;
      llamaCpp = {
        hfRepo = "mradermacher/Qwen3.6-35B-A3B-abliterated-i1-GGUF";
        quant = "IQ2_M";
      };
    };

    "qwen2.5-coder:7b" = {
      # Nothing serves this once Ollama leaves yifuwuqi; re-enable by giving
      # it a `port` (llama-cpp.nix picks it up as a unit).
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.5:4b" = {
      # Disabled: no serving backend on yifuwuqi yet (see qwen2.5-coder:7b).
      enable = false;
      tools = true;
      reasoning = false;
      targetHost = "yifuwuqi";
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3.5-4B-GGUF";
        quant = "Q8_0";
      };
    };

    # -------------------------------------------------------------------------
    # Kimi Family (Moonshot AI)
    # -------------------------------------------------------------------------
    "kimi-k2.7:code-7b" = {
      # Disabled: no serving backend on yifuwuqi yet (see qwen2.5-coder:7b).
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/moonshotai_Kimi-K2.7-Code-7B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "kimi-k2.7:code" = {
      # Disabled: no serving backend (see qwen3.6:35b-a3b).
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yitaishi";
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/moonshotai_Kimi-K2.7-Code-GGUF";
        quant = "Q4_K_M";
      };
    };

    # -------------------------------------------------------------------------
    # GLM Family (Zhipu AI)
    # -------------------------------------------------------------------------
    "glm4:latest" = {
      # Disabled: no serving backend on yifuwuqi yet (see qwen2.5-coder:7b).
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yifuwuqi";
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/glm-4-9b-chat-GGUF";
        quant = "Q4_K_M";
      };
    };

    "glm-4.7-flash:30b" = {
      # Disabled: no serving backend (see qwen3.6:35b-a3b).
      enable = false;
      tools = true;
      reasoning = true;
      targetHost = "yitaishi";
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "unsloth/GLM-4.7-Flash-GGUF";
        quant = "Q4_K_M";
      };
    };
  };

  models = filterAttrs (_n: m: m.enable or true) allModels;

  optionalAttrs = cond: attrs: if cond then attrs else { };

in
{
  local = {
    inherit models;

    opencodeModels = builtins.mapAttrs (
      n: m:
      {
        name = n;
      }
      // optionalAttrs (m.tools or false) {
        tools = true;
        tool_call = true;
      }
      // optionalAttrs (m.reasoning or false) { reasoning = true; }
      // optionalAttrs (m ? contextLength) { contextWindow = m.contextLength; }
    ) models;
  };
}
