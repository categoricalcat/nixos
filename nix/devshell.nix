_: {
  perSystem =
    { pkgs, config, ... }:
    {
      devShells.default = pkgs.mkShell {
        inherit (config.pre-commit.devShell) shellHook;
        # packages = with pkgs; [ udev ];
      };
      packages.default = config.devShells.default;
    };
}
