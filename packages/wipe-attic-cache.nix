{ pkgs }:
pkgs.writeShellApplication {
  name = "wipe-attic-cache";
  runtimeInputs = with pkgs; [
    attic-client
  ];
  text = builtins.readFile ../users/scripts/wipe-attic-cache.sh;
}
