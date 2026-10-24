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
    (prefixed "package" self.packages.${system})
    (prefixed "shell" self.devShells.${system})
  ];
}
