{
  lib,
  symlinkJoin,
  writeShellApplication,
  coreutils,
  diffutils,
  dosfstools,
  e2fsprogs,
  gnugrep,
  gnused,
  gnutar,
  gptfdisk,
  openssh,
  openssl,
  shadow,
  ssh-to-age,
  util-linux,
}:
let
  app =
    name: runtimeInputs:
    writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (./scripts + "/${name}.sh");
    };
  # setup-sops chains these; test.nix runs the identity steps directly.
  steps =
    map
      (
        name:
        app name [
          coreutils
          diffutils
          gnugrep
          openssh
          ssh-to-age
          util-linux
        ]
      )
      [
        "ensure-host-key"
        "ensure-user-key"
        "ensure-ci-key"
        "derive-age-key"
        "ssh-pub-to-age"
        "sync-secrets"
      ];
  # The mTLS mesh is the monitoring host pair; the script's address table and
  # SSH port come from the same registry the NixOS modules read, so a renumber
  # cannot desync the minted SANs. Pure builtins, so a package may import it.
  addresses = import ../modules/addresses.nix;
  inherit (addresses) hosts monitoring;
  mtlsMesh = lib.concatStringsSep " " (
    map (h: "${h}:${hosts.${h}.network.lan.ipv4.host}") [
      monitoring.centralHost
      monitoring.proxyHost
    ]
  );
  # mkSsh pins one listen port fleet-wide.
  mtlsSshPort = toString hosts.${monitoring.proxyHost}.ssh.listenPort;
  # The one host allowed to mint the CA, so a peer cannot fork the trust anchor.
  mtlsCaHost = monitoring.centralHost;

  # Two commands, two behaviours. `generate` converges (mint what is missing,
  # push what differs) and is the lane setup-sops chains; `rotate` re-signs one
  # host's pair on demand. Both libs are concatenated ahead of the command body:
  # they are functions-only, so every variable ends up owned by the file
  # shellcheck reports on and no suppression is needed.
  #
  # Both talk to peers — generate to converge the mesh, rotate to deliver a
  # re-signed pair — so both receive the SSH port and the CA host name.
  mtlsCmd =
    cmd: extraInputs:
    writeShellApplication {
      name = "mtls-pki-${cmd}";
      runtimeInputs = [
        coreutils
        openssl
      ]
      ++ extraInputs;
      text = ''
        MTLS_MESH="${mtlsMesh}"
        MTLS_CA_HOST="${mtlsCaHost}"
        MTLS_SSH_PORT="${mtlsSshPort}"
      ''
      + builtins.readFile ../packages/dev-certs/lib.sh
      + builtins.readFile ./scripts/mtls-lib.sh
      + builtins.readFile (./scripts + "/mtls-pki-${cmd}.sh");
    };
  # groupadd on the peer, openssh for the transport, gnutar for the stream.
  mtlsExtra = [
    gnutar
    openssh
    shadow
  ];
  mtlsGenerate = mtlsCmd "generate" mtlsExtra;
  mtlsRotate = mtlsCmd "rotate" mtlsExtra;
in
symlinkJoin {
  name = "secrets";
  paths = steps ++ [
    (app "setup-sops" (
      steps
      ++ [
        mtlsGenerate
        coreutils
        gnugrep
        gnused
      ]
    ))
    (app "bootstrap-disk" [
      coreutils
      dosfstools
      e2fsprogs
      gnugrep
      gptfdisk
      util-linux
    ])
    mtlsGenerate
    mtlsRotate
  ];
  meta = {
    description = "Host identity, SOPS enrollment and disk bootstrap";
    mainProgram = "setup-sops";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
