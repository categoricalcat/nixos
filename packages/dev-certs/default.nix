{
  lib,
  writeShellApplication,
  coreutils,
  jq,
  openssl,
}:
writeShellApplication {
  name = "dev-certs-setup";
  runtimeInputs = [
    coreutils
    jq
    openssl
  ];
  text = builtins.readFile ./setup.sh;
  meta = {
    description = "Mint name-constrained local development TLS certificates";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
