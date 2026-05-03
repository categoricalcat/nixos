# Provider-agnostic model registry. Each entry declares capabilities
# (`tools`, `reasoning`, `contextLength`, `yarn`) and a llama.cpp source
# (`llamaCpp.hfRepo` + `quant`) that llama-swap pulls from HuggingFace on
# first request. All consumers derive their own schema from this single map.
#
# Imported as plain data (no module args) so it works from both NixOS modules
# and home-manager modules.
#
# Consumed by:
#   - modules/services/ai/llama-swap.nix -> per-model llama-server cmd
#   - users/programs/opencode.nix        -> provider.local.models
#
# Context-length policy:
#   Per-model `contextLength` reflects what fits in the target GPU's VRAM
#   *with Q8 KV cache* (which llama-swap.nix sets globally). RPC-enabled
#   models run on yitaishi's RX 7900 XTX (24 GiB); non-RPC models run on
#   yifuwuqi's Radeon 680M (~9.6 GiB UMA budget).
#
# YaRN policy:
#   `yarn` is set ONLY for models whose target context exceeds their native
#   training window. For Qwen models that means scaling their 32k native
#   limit up to 64k or 128k. Models with native >= target (gpt-oss 128k,
#   qwen3-coder 256k, gemma3/granite4/dr1-llama-base 128k) DO NOT use YaRN
#   because YaRN slightly degrades short-context perf for no upside when
#   the native window already covers the target.
let
  models = {
    "qwen3.5:4b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Native 256k. 128k Q8 fits in yifuwuqi's 9.6 GiB UMA budget.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3.5-4B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "nemotron-nano:4b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Native 128k. Capped at 64k for concurrent headroom on the APU.
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/nvidia_Llama-3.1-Nemotron-Nano-4B-v1.1-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3:8b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Native 128k. Capped at 64k to stay within the 680M iGPU's UMA.
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3-8B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "glm-4.7-flash:30b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # MoE 30B (3B active). Native 131k. Optimized for agentic tasks.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "unsloth/GLM-4.7-Flash-GGUF";
        quant = "Q3_K_M";
      };
    };

    "mistral-nemo:12b" = {
      tools = true;
      rpc = true;
      # Native 128k. Best-in-class for sequential tool dependencies.
      contextLength = 128000;
      llamaCpp = {
        hfRepo = "bartowski/Mistral-Nemo-Instruct-2407-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma3:4b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # Native 128k. SWA + Vision-to-tool capabilities.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-3-4b-it-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma4:e2b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Native 128k. Tiny multimodal model (text-only here -- llama-swap
      # buildCmd has no --mmproj plumbing yet).
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-4-E2B-it-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma4:e4b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Native 128k. ~5.3 GB at Q4_K_M, comfortable on the 680M's UMA budget.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-4-E4B-it-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma4:26b-a4b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # MoE 26B (4B active). Native 256k, capped to 131k to mirror the
      # glm-4.7-flash:30b KV-headroom policy on the 7900 XTX.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-4-26b-a4b-it-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma4:31b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # Dense 31B. Native 256k, capped to 64k — same dense-KV policy as
      # qwen3.6:27b to leave headroom for Q8 KV cache on the 7900 XTX.
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "unsloth/gemma-4-31B-it-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.6:27b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # Dense 27B. Native 256k capped to 64k -- dense KV is heavier than
      # MoE at the same parameter count, leaving less room at long context.
      contextLength = 65536;
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3.6-27B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3.6:35b-a3b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # MoE 35B (3B active). Native 256k capped to 131k. Q3_K_M reuses the
      # VRAM budget shape already proven by glm-4.7-flash:30b.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "bartowski/Qwen_Qwen3.6-35B-A3B-GGUF";
        quant = "Q3_K_M";
      };
    };
  };

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
      // optionalAttrs (m.tools or false) { tools = true; }
      // optionalAttrs (m.reasoning or false) { reasoning = true; }
      // optionalAttrs (m ? contextLength) { contextWindow = m.contextLength; }
    ) models;
  };
}
