# Provider-agnostic model registry. Each entry declares capabilities
# (`tools`, `reasoning`, `contextLength`) and a llama.cpp source
# (`llamaCpp.hfRepo` + `quant`) that llama-swap pulls from HuggingFace on
# first request. All consumers derive their own schema from this single map.
#
# Imported as plain data (no module args) so it works from both NixOS modules
# and home-manager modules.
#
# Consumed by:
#   - modules/services/ai/llama-swap.nix -> per-model llama-server cmd
#   - modules/services/librechat.nix     -> endpoints.custom[Local].models.default
#   - users/programs/opencode.nix        -> provider.local.models
let
  contextLength = 32768;

  models = {
    "qwen3:8b" = {
      tools = true;
      reasoning = true;
      inherit contextLength;
      llamaCpp = {
        hfRepo = "Qwen/Qwen3-8B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3:4b" = {
      tools = true;
      reasoning = true;
      inherit contextLength;
      llamaCpp = {
        hfRepo = "Qwen/Qwen3-4B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen2.5:7b" = {
      tools = true;
      llamaCpp = {
        hfRepo = "Qwen/Qwen2.5-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen2.5-coder:7b" = {
      tools = true;
      inherit contextLength;
      llamaCpp = {
        hfRepo = "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gpt-oss:20b" = {
      tools = true;
      reasoning = true;
      inherit contextLength;
      llamaCpp = {
        # gpt-oss ships natively in mxfp4; F16 is the standard llama.cpp build.
        hfRepo = "ggml-org/gpt-oss-20b-GGUF";
        quant = "F16";
      };
    };

    "qwen3-coder:30b" = {
      tools = true;
      inherit contextLength;
      llamaCpp = {
        # Qwen3-Coder-30B-A3B-Instruct: MoE 30B total / 3.3B active,
        # explicitly trained for long-horizon agentic tool use. Q3_K_M
        # at ~14.8 GB is the sweet spot for this host's 19 GiB UMA;
        # active-params count keeps token throughput at 8B-class
        # speeds despite the 30B nameplate. unsloth's repo because
        # their Dynamic 2.0 quants outperform stock at the same file
        # size and llama.cpp pulls them via -hf cleanly.
        hfRepo = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
        quant = "Q3_K_M";
      };
    };

    "deepseek-r1-tools:8b" = {
      tools = true;
      reasoning = true;
      inherit contextLength;
      llamaCpp = {
        # bartowski's reupload patches the chat template so tool calls work,
        # which the upstream deepseek-r1 distill template does not.
        hfRepo = "bartowski/DeepSeek-R1-Distill-Llama-8B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "granite4:3b" = {
      tools = true;
      llamaCpp = {
        hfRepo = "ibm-granite/granite-3.3-2b-instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma3:4b" = {
      tools = true;
      reasoning = true;
      inherit contextLength;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-3-4b-it-GGUF";
        quant = "Q4_K_M";
      };
    };
  };

  optionalAttrs = cond: attrs: if cond then attrs else { };

  toolCapable = builtins.filter (n: models.${n}.tools or false) (builtins.attrNames models);
in
{
  local = {
    inherit models;

    librechatDefaults = toolCapable;

    opencodeModels = builtins.mapAttrs (
      n: m:
      {
        name = n;
      }
      // optionalAttrs (m.tools or false) { tools = true; }
      // optionalAttrs (m.reasoning or false) { reasoning = true; }
      // optionalAttrs (m ? contextLength) { contextWindow = m.contextLength; }
    ) models;
  };
}
