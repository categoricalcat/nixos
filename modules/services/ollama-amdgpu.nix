{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ollama-amdgpu;
in
{
  options.services.ollama-amdgpu = {
    enable = lib.mkEnableOption "Ollama with AMD GPU support";

    rocmTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of ROCm targets to compile for (e.g. [ \"gfx1100\" ]).";
    };

    rocmOverrideGfx = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HSA_OVERRIDE_GFX_VERSION for Ollama ROCm.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config = {
      cudaSupport = false;
      rocmSupport = true;
      inherit (cfg) rocmTargets;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.amdgpu = {
      opencl.enable = true;
    };

    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      rocmOverrideGfx = lib.mkIf (cfg.rocmOverrideGfx != null) cfg.rocmOverrideGfx;
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmOverrideGfx;
      };
    };
  };
}
