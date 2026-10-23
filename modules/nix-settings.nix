{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./services/attic/client.nix
  ];

  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/inputs/${name}";
    value.source = value.outPath;
  }) (lib.filterAttrs (name: _: name != "self") inputs);

  nix = {
    registry = lib.mapAttrs (_: flake: { inherit flake; }) inputs;

    settings = {
      nix-path = [ "/etc/nix/inputs" ];
      allowed-users = [ "root" ] ++ builtins.attrNames config.users.users;
      auto-optimise-store = true;
      trusted-users = lib.mkAfter [
        "root"
        "nix-builder"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      accept-flake-config = false;
      # download-buffer-size = lib.mkDefault (1024 * 1024 * 1024 * 10);

      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
        "https://niri.cachix.org"
        "https://musnix.cachix.org"
        "https://cache.numtide.com"
        "https://pre-commit-hooks.cachix.org"
        "https://cache.thalheim.io"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "musnix.cachix.org-1:EDlNXnpEVLgjuxKuiB5xJrEmVge1h3W7GqAe7L0zs+M="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
        "cache.thalheim.io-1:R7msbosLEZKrxk/lKxf9BTjOOH7Ax3H0Qj0/6wiHOgc="
      ];
    };
  };
}
