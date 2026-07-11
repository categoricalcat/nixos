{ pkgs, lib, ... }:

{
  _module.args.allAddresses = import ./addresses.nix;

  imports = [
    ./nix-ld.nix
    ./server-mode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  nix.package = lib.mkForce pkgs.lix;
  nixpkgs.config.allowUnfree = true;
  # nixpkgs.overlays = [
  #   (_final: prev: {
  #     pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
  #       (_python-final: python-prev: {
  #         click-threading = python-prev.click-threading.overridePythonAttrs (_old: {
  #           doCheck = false;
  #         });
  #       })
  #     ];
  #   })
  # ];
  environment.defaultPackages = lib.mkForce [ ];
}
