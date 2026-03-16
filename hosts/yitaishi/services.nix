{
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/services/zerotier.nix
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    };
  };
}
