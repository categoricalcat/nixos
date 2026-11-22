{ pkgs, antigravityCli }:
{

  diff-to-commit = pkgs.writeShellScriptBin "diff-to-commit" (
    builtins.readFile ../nix/scripts/diff-to-commit.sh
  );

  lock-to-changelog = pkgs.writeShellScriptBin "lock-to-changelog" (
    builtins.readFile ../nix/scripts/lock-to-changelog.sh
  );

  # nixpkgs ships the Antigravity CLI as `antigravity-cli` with an `agy` binary;
  # the pin comes from flake.lock's nixpkgs, so the agent binary stays locked.
  nxd-agy = pkgs.writeShellScriptBin "nxd-agy" ''
    exec ${pkgs.lib.getExe antigravityCli} "$@"
  '';

  nxd-agent = pkgs.writeShellScriptBin "nxd-agent" ''
    exec nix run github:numtide/nix-ai-tools#cursor-agent -- "$@"
  '';

  nxd-opencode = pkgs.writeShellScriptBin "nxd-opencode" ''
    exec nix run github:anomalyco/opencode#opencode -- "$@"
  '';

  seenix = pkgs.callPackage ./seenix { };
}
