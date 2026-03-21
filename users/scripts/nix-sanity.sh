nix-sanity() (
  nix fmt
  git add .
  nix flake check -v
  sudo nixos-rebuild --flake ".#$HOST" --upgrade --print-build-logs --show-trace dry-build
)
