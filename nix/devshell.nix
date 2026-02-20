_: {
  perSystem =
    { pkgs, config, ... }:
    {
      devShells.default = pkgs.mkShell {
        inherit (config.pre-commit.devShell) shellHook;

        # packages = with pkgs; [ udev ];

        strictDeps = true;
        nativeBuildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          rust-analyzer
        ];

        RUST_SRC_PATH = with pkgs; "${rustPlatform.rustLibSrc}";
      };

      packages.default = config.devShells.default;

    };
}
