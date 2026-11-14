# NixOS, Home Manager, and `flake-parts` Module Patterns

Use this reference when authoring or refactoring NixOS, Home Manager, or `flake-parts` modules.

## Module anatomy and naming

- Accept only needed module arguments (`{ config, lib, pkgs, ... }:`).
- Bind `let cfg = config.services.<name>; in` only when `cfg` has 2+ consumers; inline single-use lookups directly.
- Structure modules with `{ imports = [ ... ]; options = { ... }; config = lib.mkIf cfg.enable { ... }; }` when declaring both options and conditional configuration; omit top-level `options`/`config` wrappers in pure configuration modules.
- Name custom options in `lowerCamelCase` (`openFirewall`, `stateDir`, `extraFlags`).

## Fixed-point and laziness invariants

- **Static `imports`:** Never condition `imports` on `config` (`imports = lib.optionals config.foo.enable [ ./bar.nix ];` causes infinite recursion). Import `./bar.nix` unconditionally and gate its body with `config = lib.mkIf cfg.enable { ... };`.
- **Lazy conditionals (`lib.mkIf` and `lib.mkMerge`):** Never use strict `if config.foo then { ... } else { ... }` or `lib.recursiveUpdate` to assemble module `config` attrsets—strict evaluation forces option values before the module fixpoint converges.
- **Never shallow-merge `lib.mkIf` blocks:** `(lib.mkIf a { ... }) // (lib.mkIf b { ... })` silently drops the first block because `lib.mkIf` returns a tagged `{ _type = "if"; condition = ...; content = ...; }` attrset. Combine multiple conditional blocks with `lib.mkMerge [ (lib.mkIf a { ... }) (lib.mkIf b { ... }) ]`.
- **Ordered list and string merging:** Use `lib.mkBefore`, `lib.mkAfter`, or `lib.mkOrder <priority>` when ordering lines, scripts, or arguments across modules rather than assuming evaluation order.
- **Static `specialArgs`:** Keep `specialArgs` and `extraSpecialArgs` strictly for static flake inputs (`{ inherit inputs global; }`). Never pass `config`-derived values through `specialArgs`; pass shared configuration via module options instead.
- **No Import From Derivation (IFD):** Never `import` or `builtins.readFile` a derivation output during module evaluation; IFD serializes evaluation on builds and breaks `nix flake show` / `nix flake check --no-build`.

## Option declarations (`lib.types` and RFC 42)

- Use `lib.mkEnableOption "<description>"` for boolean toggles and `lib.mkPackageOption pkgs "<pkg>" { }` for overridable package options.
- Constrain option types strictly (`lib.types.port`, `lib.types.path`, `lib.types.ints.unsigned`, `lib.types.enum [ ... ]`, `lib.types.attrsOf (lib.types.submodule { ... })`). Avoid untyped `lib.types.attrs` or unconstrained `lib.types.str` when structure or domain bounds are known.
- **RFC 42 `settings` pattern:** For services configured via structured files (TOML, YAML, JSON, INI), expose a freeform `settings` option backed by `pkgs.formats.<fmt>` so upstream keys work without manual wrapper boilerplate:

```nix
let
  settingsFormat = pkgs.formats.toml { };
in
{
  options.services.example.settings = lib.mkOption {
    type = settingsFormat.type;
    default = { };
    description = "Configuration written to example.toml.";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.example.serviceConfig.ExecStart =
      "${lib.getExe cfg.package} --config ${settingsFormat.generate "example.toml" cfg.settings}";
  };
}
```

- Enforce cross-option and host invariants with `assertions` (and surface non-fatal deprecations or caveats via `warnings`).

## Override priorities and side effects

- **Priority hierarchy:**
  - `lib.mkDefault` (priority `1000`): defaults in shared role/profile modules that hosts may override cleanly.
  - Normal definition (priority `100`): standard host or profile values.
  - `lib.mkForce` (priority `50`): last-resort override when an upstream module provides no option for a setting. Every `lib.mkForce` must carry a comment explaining why normal priority is insufficient.
- **No unrequested host side effects:** Service modules must not unconditionally mutate `networking.firewall.*` or `environment.systemPackages`. Gate firewall rules behind an `openFirewall` option (`default = false;`) and keep CLI package installation explicit unless central to enabling a user program module (`programs.<name>.enable`).

## Runtime secrets and systemd hardening

- **Never leak secrets into `/nix/store`:** Interpolating secret files (`"${secretFile}"`), `builtins.readFile` on secret material, or passing secret values in `systemd.services.<name>.environment` writes plaintext world-readable (`0444`) into `/nix/store`.
- Wire `config.sops.secrets.<name>.path` at runtime via systemd `LoadCredential = "token:${config.sops.secrets.<name>.path}"` (reading from `$CREDENTIALS_DIRECTORY/token`), `EnvironmentFile`, or the daemon's native secret-file directive (e.g. `{file:/run/secrets/...}`).
- Prefer `DynamicUser = true` (or a dedicated system user/group when persistent ownership across restarts requires fixed UIDs) alongside `StateDirectory`, `CacheDirectory`, and `RuntimeDirectory` rather than imperative `mkdir`/`chown` in `preStart`.
- Add a `pkgs.testers.runNixOSTest` VM test for non-trivial multi-unit daemons, firewall/routing rules, or failover logic.

## `flake-parts` scoping

- Inside `perSystem = { config, self', inputs', pkgs, ... }:`, reference same-system outputs via `config.packages.<name>` (or `self'.packages.<name>`) and input packages via `inputs'.<input>.packages.<name>`.
- Never hardcode `self.packages.x86_64-linux.<name>` inside `perSystem`.
- When top-level `flake` outputs (`nixosConfigurations`, `deploy`) need `perSystem` values, bridge explicitly via `withSystem "<system>" ({ config, ... }: ...)` rather than indexing raw `self` system maps.
