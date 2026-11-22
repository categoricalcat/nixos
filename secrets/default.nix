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
  gptfdisk,
  openssh,
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
in
symlinkJoin {
  name = "secrets";
  paths = steps ++ [
    (app "setup-sops" (
      steps
      ++ [
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
  ];
  meta = {
    description = "Host identity, SOPS enrollment and disk bootstrap";
    mainProgram = "setup-sops";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
