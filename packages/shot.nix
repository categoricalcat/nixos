{ pkgs }:

pkgs.writeShellApplication {
  name = "shot";
  runtimeInputs = with pkgs; [
    grim
    slurp
    jq
    ffmpeg
    ksnip
  ];
  text = builtins.readFile ../nix/scripts/shot.sh;
}
