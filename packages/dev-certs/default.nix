{
  lib,
  symlinkJoin,
  writeShellApplication,
  coreutils,
  gnugrep,
  gnutar,
  jq,
  openssh,
  openssl,
  shadow,
}:
let
  addresses = import ../../modules/addresses.nix;
  sshPort = toString addresses.hosts.${addresses.monitoring.proxyHost}.ssh.listenPort;

  meta = description: {
    inherit description;
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
in
symlinkJoin {
  name = "dev-certs";
  paths = [
    (writeShellApplication {
      name = "dev-certs-generate";
      runtimeInputs = [
        coreutils
        jq
        openssl
      ];
      # generate.sh uses the shared leaf extension profile from lib.sh.
      text = builtins.readFile ./lib.sh + builtins.readFile ./generate.sh;
      meta = meta "Mint name-constrained local development TLS certificates";
    })
    (writeShellApplication {
      name = "dev-certs-push";
      runtimeInputs = [
        coreutils
        gnutar # certs_push's stream
        openssh # certs_push's transport
        shadow # groupadd on the peer, via certs_push
      ];
      # push.sh needs the shared copy helper and the fleet's sshd port, which
      # comes from the registry rather than a literal.
      text = ''
        SSH_PORT="${sshPort}"
      ''
      + builtins.readFile ./lib.sh
      + builtins.readFile ./push.sh;
      meta = meta "Hand the dev certificates to peers";
    })
    (writeShellApplication {
      name = "dev-certs-copy";
      runtimeInputs = [
        coreutils
        gnugrep
      ];
      text = builtins.readFile ./copy.sh;
      meta = meta "Copy the dev leaf into a folder (default: .)";
    })
  ];
  meta = meta "Name-constrained local development TLS certificates (generate, push, project copy)";
}
