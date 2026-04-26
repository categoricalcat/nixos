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
    "qwen3:8b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      contextLength = 131072;
      yarn = {
        origCtx = 32768;
        scale = 4;
      };
      llamaCpp = {
        hfRepo = "Qwen/Qwen3-8B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen3:4b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Capped at 64k: non-RPC, runs on the 680M iGPU's ~7 GiB free UMA
      # after weights. Standard GQA (no SWA), so KV grows linearly --
      # 128k Q8 would hit ~9 GiB and OOM.
      contextLength = 65536;
      yarn = {
        origCtx = 32768;
        scale = 2;
      };
      llamaCpp = {
        hfRepo = "Qwen/Qwen3-4B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen2.5:7b" = {
      tools = true;
      rpc = true;
      contextLength = 131072;
      yarn = {
        origCtx = 32768;
        scale = 4;
      };
      llamaCpp = {
        hfRepo = "Qwen/Qwen2.5-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "qwen2.5-coder:7b" = {
      tools = true;
      rpc = true;
      contextLength = 131072;
      yarn = {
        origCtx = 32768;
        scale = 4;
      };
      llamaCpp = {
        hfRepo = "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gpt-oss:20b" = {
      tools = true;
      reasoning = true;
      rpc = true;
      # Native 128k. SWA + GQA give it unusually small KV (~37 KB/token),
      # so 128k fits comfortably in the 7900 XTX with weights.
      contextLength = 131072;
      llamaCpp = {
        # gpt-oss ships natively in mxfp4; F16 is the standard llama.cpp build.
        hfRepo = "ggml-org/gpt-oss-20b-GGUF";
        quant = "F16";
      };
    };

    "qwen3-coder:30b" = {
      tools = true;
      rpc = true;
      # Native 256k. 192k at Q8 KV uses ~9.4 GiB which fits on the 7900
      # XTX after the 14.8 GiB Q3_K_M weights. Going to 256k would need
      # ~12.6 GiB KV with no headroom for compute buffers, so we cap at
      # 192k. Repository-scale enough for agentic coding.
      contextLength = 131072;
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
      rpc = true;
      # Native 128k via the Llama-3 backbone, no YaRN needed.
      contextLength = 131072;
      llamaCpp = {
        # bartowski's reupload patches the chat template so tool calls work,
        # which the upstream deepseek-r1 distill template does not.
        hfRepo = "bartowski/DeepSeek-R1-Distill-Llama-8B-GGUF";
        quant = "Q4_K_M";
      };
    };

    "granite4:3b" = {
      tools = true;
      rpc = false;
      # Granite 3.3 2B is tiny (~1.5 GB at Q4) and has small KV; 128k fits
      # easily in the 680M's UMA budget.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ibm-granite/granite-3.3-2b-instruct-GGUF";
        quant = "Q4_K_M";
      };
    };

    "gemma3:4b" = {
      tools = true;
      reasoning = true;
      rpc = false;
      # Gemma3 uses 5:1 interleaved sliding-window attention so effective
      # KV is ~5x smaller than a flat-attention model the same size --
      # 128k fits comfortably in the 680M's UMA budget.
      contextLength = 131072;
      llamaCpp = {
        hfRepo = "ggml-org/gemma-3-4b-it-GGUF";
        quant = "Q4_K_M";
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
