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

  nxd-cursor = pkgs.writeShellScriptBin "nxd-cursor" ''
    exec nix run github:jacopone/code-cursor-nix#cursor -- "$@"
  '';

  nxd-antigravity = pkgs.writeShellScriptBin "nxd-antigravity" ''
    exec nix run github:jacopone/antigravity-nix#google-antigravity-ide -- "$@"
  '';

  nxd-opencode = pkgs.writeShellScriptBin "nxd-opencode" ''
    exec nix run github:anomalyco/opencode#opencode -- "$@"
  '';
}
