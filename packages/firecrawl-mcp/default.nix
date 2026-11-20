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
  nodeTypesVersion = "24.19.2";
  nodeTypes =
    npmTarball "@types/node" nodeTypesVersion
      "sha256-4BzJC9r7FClfFajfvN3TeDQlDp36tHY/9ob7dRkV2c4=";
  # Hard dep of @types/node 24 (fetch/Response globals).
  undiciTypes =
    npmTarball "undici-types" "7.24.6"
      "sha256-Kr9ZWoa4fdIpUSGISOxK2JwBjbDmVnFtwEuLL5KQoPQ=";

  # Unpack a vendored npm tarball into a shared node_modules tree for both the
  # Nix build and the devShell (so tsserver resolves @types/node in-editor).
  # The tarball's single root dir is not stable across releases (e.g. "node
  # v24.19"), so extract whatever it is. cut+sort drain the listing fully;
  # head would SIGPIPE tar into a spurious build failure.
  nodeModules = stdenv.mkDerivation {
    pname = "firecrawl-mcp-node-modules";
    version = nodeTypesVersion;
    dontUnpack = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      npmUnpack() {
        local dest=$1 tarball=$2 root
        root=$(tar -tf "$tarball" | cut -d/ -f1 | sort -u)
        tar -xf "$tarball"
        mv "$root" "$dest"
      }
      # Nested one level deep: tsc realpaths the node_modules symlink, then
      # resolves undici-types by walking ancestors of the real store path —
      # which only finds a dir literally named node_modules at the store root.
      mkdir -p "$out/node_modules/@types"
      npmUnpack "$out/node_modules/@types/node" ${nodeTypes}
      npmUnpack "$out/node_modules/undici-types" ${undiciTypes}
    '';
  };
in
stdenv.mkDerivation {
  pname = "firecrawl-mcp";
  version = "1.1.5";

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

    ln -s ${nodeModules}/node_modules node_modules

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

  passthru = {
    inherit nodeModules;
  };

  meta = {
    description = "Zero-dependency MCP stdio server: SearXNG search (1:1 params) + self-hosted Firecrawl scrape";
    platforms = lib.platforms.linux;
    mainProgram = "firecrawl-mcp";
  };
}
