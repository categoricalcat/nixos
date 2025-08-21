# Pre-commit hooks configuration
{
  system,
  nixpkgs,
  pre-commit-hooks,
  ...
}:

let
  pkgs = import nixpkgs { inherit system; };
in
pre-commit-hooks.lib.${system}.run {
  src = ../.;
  hooks = {
    # Check formatting without modifying files
    nix-fmt-check = {
      enable = true;
      name = "nix fmt check";
      entry = "${pkgs.writeShellScript "nix-fmt-check" ''
        echo "Checking formatting..."
        nix fmt -- --ci
      ''}";
      files = "\\.nix$";
      pass_filenames = false;
    };

    # Run flake check
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
}
