{
  lib,
  symlinkJoin,
  writeShellApplication,
  coreutils,
  gnugrep,
  jq,
  openssl,
}:
let
  app =
    name: description: runtimeInputs: file:
    writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile file;
      meta = {
        inherit description;
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    };
in
symlinkJoin {
  name = "dev-certs";
  paths = [
    (app "dev-certs-setup" "Mint name-constrained local development TLS certificates" [
      coreutils
      jq
      openssl
    ] ./setup.sh)
    (app "dev-certs-copy" "Copy the dev leaf into a folder (default: .)" [
      coreutils
      gnugrep
    ] ./copy.sh)
  ];
  meta = {
    description = "Name-constrained local development TLS certificates (setup and project copy)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
