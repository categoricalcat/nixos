{ self, lib, ... }:
let
  system = "x86_64-linux";
  prefixed = prefix: lib.mapAttrs' (name: lib.nameValuePair "${prefix}-${name}");
in
{
  flake.hydraJobs = lib.mergeAttrsList [
    self.checks.${system}
    (prefixed "nixos" (
      lib.mapAttrs (_: host: host.config.system.build.toplevel) self.nixosConfigurations
    ))
    # package-<name> already lives in checks, so flake check and hydraJobs
    # build the same derivation.
    (prefixed "shell" self.devShells.${system})
  ];
}
