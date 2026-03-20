nix-sanity() {
  set -e
  nix fmt
  git add .
  nix flake check -v
  sudo nixos-rebuild --flake ".#$HOST" --upgrade --print-build-logs --show-trace dry-build
  set +e
}
