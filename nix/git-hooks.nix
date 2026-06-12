_: {
  perSystem =
    { pkgs, ... }:
    {
      pre-commit = {
        check.enable = true;
        settings.hooks = {
          treefmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;

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
