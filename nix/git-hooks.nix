_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      pre-commit = {
        check.enable = true;
        settings.hooks = {
          treefmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;

          # Repo-wide JS/TS lint (perfectionist + unicorn + typescript-eslint
          # recommended, untyped), all resolved inside the eslint-env
          # derivation (nix/eslint).
          eslint = {
            enable = true;
            package = config.packages.eslint-env;
            files = "\\.(js|ts)$";
          };

          nixf-diagnose = {
            enable = true;
            name = "nixf-diagnose";
            description = "Run nixf-diagnose to catch semantic errors";
            entry = "${pkgs.nixf-diagnose}/bin/nixf-diagnose";
            files = "\\.nix$";
          };

          flake-check = {
            enable = false;
            name = "nix flake check";
            entry = "${pkgs.writeShellScript "flake-check" ''
              echo "Running flake check..."
              nix flake check --no-build
            ''}";
            files = "\\.(nix|lock)$";
            pass_filenames = false;
          };
        };
      };
    };
}
