{ pkgs }:
{

  diff-to-commit = pkgs.writeShellScriptBin "diff-to-commit" (
    builtins.readFile ../nix/scripts/diff-to-commit.sh
  );

  nxd-agy = pkgs.writeShellScriptBin "nxd-agy" ''
    exec nix run github:jacopone/antigravity-nix#google-antigravity-cli -- "$@"
  '';

  nxd-agent = pkgs.writeShellScriptBin "nxd-agent" ''
    exec nix run github:numtide/nix-ai-tools#cursor-agent -- "$@"
  '';

  nxd-opencode = pkgs.writeShellScriptBin "nxd-opencode" ''
    exec nix run github:anomalyco/opencode#opencode -- "$@"
  '';

  seenix = import ./see.nix { inherit pkgs; };
}
