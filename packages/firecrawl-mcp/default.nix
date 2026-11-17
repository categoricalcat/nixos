{
  lib,
  stdenv,
  fetchurl,
  typescript,
  nodejs,
  makeWrapper,
}:

let
  # This nixpkgs pin removed nodePackages and has no top-level @types/node;
  # vendored from npm with fixed hashes. Dev-time types only — nothing is
  # installed at runtime. 7.24.6 is the max allowed by @types/node 24.19.2's
  # ">=7.24.0 <7.24.7" range.
  npmTarball =
    name: version: hash:
    fetchurl {
      url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
      inherit hash;
    };
  nodeTypes =
    npmTarball "@types/node" "24.19.2"
      "sha256-4BzJC9r7FClfFajfvN3TeDQlDp36tHY/9ob7dRkV2c4=";
  # Hard dep of @types/node 24 (fetch/Response globals).
  undiciTypes =
    npmTarball "undici-types" "7.24.6"
      "sha256-Kr9ZWoa4fdIpUSGISOxK2JwBjbDmVnFtwEuLL5KQoPQ=";
in
stdenv.mkDerivation {
  pname = "firecrawl-mcp";
  version = "1.0.0";

  # Only the build inputs, so editing default.nix never changes the store hash.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./firecrawl-mcp.ts
      ./package.json
      ./tsconfig.json
    ];
  };

  strictDeps = true;

  nativeBuildInputs = [
    makeWrapper
    typescript
  ];

  buildPhase = ''
    runHook preBuild

    # Unpack a vendored npm tarball into node_modules/<name>. The tarball's
    # single root dir is not stable across releases (e.g. "node v24.19"), so
    # extract whatever it is. cut+sort drain the listing fully; head would
    # SIGPIPE tar into a spurious build failure.
    npmUnpack() {
      local name=$1 tarball=$2 root
      root=$(tar -tf "$tarball" | cut -d/ -f1 | sort -u)
      tar -xf "$tarball"
      mv "$root" "node_modules/$name"
    }
    mkdir -p node_modules/@types
    npmUnpack "@types/node" ${nodeTypes}
    npmUnpack "undici-types" ${undiciTypes}

    # Strictest gate: any type error fails the build (noEmit; node runs the
    # .ts itself via native type stripping).
    tsc -p tsconfig.json
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 firecrawl-mcp.ts $out/lib/firecrawl-mcp/firecrawl-mcp.ts
    install -Dm644 package.json $out/lib/firecrawl-mcp/package.json
    makeWrapper ${lib.getExe nodejs} $out/bin/firecrawl-mcp \
      --add-flags "$out/lib/firecrawl-mcp/firecrawl-mcp.ts"
    runHook postInstall
  '';

  meta = {
    description = "Zero-dependency MCP stdio server for a self-hosted Firecrawl instance";
    platforms = lib.platforms.linux;
    mainProgram = "firecrawl-mcp";
  };
}
