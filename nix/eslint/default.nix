{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  makeWrapper,
  nodejs,
}:
buildNpmPackage {
  pname = "eslint-env";
  version = "1.0.0";

  # Update dependencies (from the devshell; commit first so the flake's git
  # filter sees the files):
  #   nix-update --flake --version=skip --generate-lockfile eslint-env
  # Lint stays untyped: typescript exists solely for @typescript-eslint's
  # parser, whose peer range is >=4.8.4 <6.1.0 — hence ~6.0.0 in package.json,
  # capped below 6.1 until typescript-eslint widens it. TS 7 is unusable for
  # linting; the repo's type gate remains the pin's typescript_7 at build.

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./eslint.config.js
    ];
  };

  # npmDeps sees only the manifest and the lockfile, so editing eslint.config.js
  # never invalidates the dependency hash.
  npmDeps = fetchNpmDeps {
    name = "eslint-env-npm-deps";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./package.json
        ./package-lock.json
      ];
    };
    hash = "sha256-4k0XEjUMv/eYwz3Zke8l55sMvr12kFH9IsGE/Vhikgs=";
  };

  # No build script; node_modules is produced by npmConfigHook.
  dontNpmBuild = true;
  # All dependencies are the shipped tool — nothing to prune away.
  dontNpmPrune = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/eslint-env
    cp -a node_modules $out/lib/eslint-env/
    # The config must sit at the package root next to node_modules: its
    # plugin imports resolve relative to its own directory.
    install -Dm644 eslint.config.js $out/lib/eslint-env/eslint.config.js
    makeWrapper ${lib.getExe nodejs} $out/bin/eslint \
      --add-flags "$out/lib/eslint-env/node_modules/eslint/bin/eslint.js" \
      --add-flags "--config $out/lib/eslint-env/eslint.config.js"
    runHook postInstall
  '';

  meta = {
    description = "Repo-wide ESLint for JavaScript and TypeScript (perfectionist, unicorn, typescript-eslint)";
    platforms = lib.platforms.linux;
    mainProgram = "eslint";
  };
}
