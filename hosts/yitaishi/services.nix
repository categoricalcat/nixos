{
  ...
}:
{
  imports = [
    ../../modules/services/tailscale.nix
    ../../modules/services/zerotier.nix
    ../../modules/services/ollama-amdgpu.nix
    ../../modules/services/syncthing
  ];

  services.ollama-amdgpu = {
    enable = true;
    rocmTargets = [ "gfx1100" ];
    rocmOverrideGfx = "11.0.0";
  };
}
