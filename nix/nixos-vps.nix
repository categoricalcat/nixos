# VPS NixOS configuration (FRP server)
{
  nixpkgs,
  sops-nix,
  nixowos,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    ../secrets/sops.nix
    ../vps/configuration.nix
  ];
}
