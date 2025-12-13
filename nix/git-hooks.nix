_: {
  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit = {
        check.enable = false;
        settings.hooks = {
          treefmt.enable = true;
          treefmt.package = config.treefmt.build.wrapper;

          flake-check = {
            enable = true;
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
