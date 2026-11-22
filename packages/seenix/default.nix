{
  coreutils,
  hostname,
  nix,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "seenix";
  runtimeInputs = [
    coreutils
    hostname
    nix
    python3
  ];
  # Deliberate eval-time store copy: the server script is a runtime asset.
  runtimeEnv.SEENIX_SERVE_PY = "${./serve.py}";
  text = builtins.readFile ./seenix.sh;
}
