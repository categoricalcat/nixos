{ pkgs }:
pkgs.writeShellApplication {
  name = "wipe-attic-cache";
  runtimeInputs = with pkgs; [
    attic-client
    coreutils
    findutils
    postgresql
    systemd
    util-linux
  ];
  text = builtins.readFile ../users/scripts/wipe-attic-cache.sh;
}
