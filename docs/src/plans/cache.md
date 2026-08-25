# CI/CD & Binary Cache Plan

## Objective

Turn yifuwuqi into a build server that:

1. Builds NixOS closures on every push/PR (CD, not just CI)
1. Serves the resulting `/nix/store` paths as a binary cache over Tailscale
1. Lets every mesh host pull pre-built closures instead of rebuilding locally

## Architecture

```text
GitHub push/PR
       │
       ▼
┌──────────────────────────────────────┐
│  GitHub Actions (flake-ci.yml)       │
│                                      │
│  PR / push ──► check job             │  yifuwuqi runner
│                (fmt, flake check)    │  (self-hosted)
│                                      │
│  push to main/develop                │
│  + PR if author == repo owner        │
│         │                            │
│         ▼                            │
│         build job                    │  yifuwuqi runner
│         (nix build all hosts)        │  (closures to store)
└──────────────────────────────────────┘
       │
       ▼  builds land in /nix/store
┌──────────────────────────────────────┐
│  yifuwuqi                            │
│                                      │
│  harmonia ──► cache.fufu.land        │
│  (serves /nix/store over HTTPS)      │
└──────────────────────────────────────┘
       │  HTTPS (via cache.fufu.land)
       ▼
┌──────────────────────────────────────┐
│  yitaishi, yixiaoqing, yirukou       │
│                                      │
│  nix.settings.substituters =         │
│    [ "https://cache.fufu.land" ]     │
│                                      │
│  nixos-rebuild switch pulls          │
│  pre-built paths from yifuwuqi       │
└──────────────────────────────────────┘
```

______________________________________________________________________

## 1. Single Workflow Integration

Instead of splitting into two files, we will run the entire pipeline in `.github/workflows/flake-ci.yml` using the self-hosted runner.

### Moving Jobs to Self-Hosted

We will move the pipeline to the `self-hosted` runner (yifuwuqi) to take advantage of the persistent `/nix/store` and avoid the slow Nix installation on GitHub-hosted runners.

1. **`check` job:**

   - **Runner:** `self-hosted` (yifuwuqi)
   - **Actions:** Run `nix fmt` and `nix flake check`.
   - *Note:* Since `nix flake check` comprehensively evaluates the flake, the old `eval` job becomes redundant and should be **removed**.

1. **`generate-matrix` job:**

   - **Runner:** `self-hosted` (yifuwuqi)
   - **Actions:** Evaluates the flake to generate the list of hosts.

1. **New `build` job:**

   - **Depends on:** `generate-matrix` (and optionally `check`)
   - **Runner:** `self-hosted` (yifuwuqi)
   - **Strategy:** Set `fail-fast: true` for the matrix. If any host fails to build or any earlier step fails, the entire workflow and all parallel jobs will be cancelled immediately to save resources.
   - **Security guard:** `if: github.actor == github.repository_owner`
     - Runs only if the PR author or pusher is you.
     - Skips external PRs from forks automatically.
   - **Actions:** `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` per host.
   - Closures land directly in yifuwuqi's `/nix/store` — Harmonia serves them automatically.

*Note: Since all jobs run on a self-hosted NixOS runner, we no longer need `cachix/install-nix-action` or `nix-community/cache-nix-action`.*

No explicit cache push step needed. Harmonia serves whatever is in the store.

______________________________________________________________________

## 2. Self-Hosted GitHub Runner

The module already exists at `modules/services/github-runner.nix`.

### Changes needed

1. **Enable:** Uncomment the import in `hosts/yifuwuqi/services.nix`
1. **Provision token:** Ensure `tokens/github-runner-nixos` is in sops secrets
1. **Add nix to runner packages:** The runner needs `nix` available to build

### Runner security properties (NixOS defaults)

- `DynamicUser=yes` — ephemeral UID, no persistent home
- Private `/tmp` — each job gets isolation
- Only triggers for repo owner on PRs (workflow guard)
- No secrets exposed beyond the runner token

### Why a systemd service, not a container?

The NixOS module runs as a sandboxed systemd service, not in a podman/microVM
container. This is fine because:

1. The actor gate ensures only the repo owner's code runs — no adversarial input
1. The runner needs `/nix/store` access to build, which would punch through
   container isolation anyway
1. Systemd sandboxing (`DynamicUser`, `PrivateTmp`, `ProtectSystem`) already
   prevents persistent state and limits blast radius

Container isolation is mainly valuable for untrusted code. If the actor gate is
ever removed (e.g., to allow collaborators), revisit this with a microVM-based
runner like [github-nix-ci](https://github.com/juspay/github-nix-ci) or
ephemeral podman containers.

______________________________________________________________________

## 3. Binary Cache: Harmonia

### Setup on yifuwuqi

#### Generate signing keypair

```bash
nix-store --generate-binary-cache-key yifuwuqi-cache /persist/keys/harmonia/cache-priv-key.pem /persist/keys/harmonia/cache-pub-key.pem
```

#### NixOS module (`modules/services/harmonia.nix`)

```nix
{ ... }:

{
  services.harmonia = {
    enable = true;
    signKeyPath = "/persist/keys/harmonia/cache-priv-key.pem";
    settings.bind = "0.0.0.0:5000";
  };

  # Allow cache traffic from the local network (for nginx proxy)
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
```

#### Import in `hosts/yifuwuqi/services.nix`

```nix
../../modules/services/harmonia.nix
```

#### Expose via Nginx (`modules/services/nginx-proxy.nix`)

Add the cache endpoint to your existing nginx configuration:

```nix
      "cache.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://''${yifuwuqiLan}:5000";
        };
      };
```

### Client configuration (all mesh hosts)

Add to `modules/nix-settings.nix` (or a new `modules/binary-cache.nix`):

```nix
nix.settings = {
  substituters = [
    "https://cache.fufu.land"
    "https://nix-community.cachix.org"
    "https://cache.nixos.org/"
  ];
  trusted-public-keys = [
    "yifuwuqi-cache:<contents-of-cache-pub-key.pem>"
    # ... existing keys ...
  ];
};
```

> **Note:** We expose harmonia behind the existing `nginx-proxy.nix` setup at
> `https://cache.fufu.land`. This provides standard TLS and avoids hardcoding
> Tailscale IPs in the substituters list.

______________________________________________________________________

## 4. Implementation Phases

### Phase 1: Harmonia

1. Generate signing keypair on yifuwuqi
1. Create `modules/services/harmonia.nix`
1. Import in `hosts/yifuwuqi/services.nix`
1. Add yifuwuqi as substituter in `modules/nix-settings.nix`
1. Deploy to yifuwuqi, verify other hosts can pull from it

### Phase 2: Self-hosted runner

1. Provision `tokens/github-runner-nixos` in sops
1. Uncomment github-runner import in `hosts/yifuwuqi/services.nix`
1. Add `nix` to runner's `extraPackages`
1. Deploy, verify runner appears in GitHub repo settings

### Phase 3: CD workflow

1. Create `.github/workflows/flake-cd.yml`
1. Test with a push to `develop`
1. Verify closures land in yifuwuqi's store
1. Verify another host can pull them via harmonia

### Phase 4: Wire it all together

1. Ensure `distributed-builds.nix` `builders-use-substitutes` picks up the
   harmonia substituter (it already does — builders use the host's configured
   substituters)
1. Consider updating `system.autoUpgrade` on other hosts to benefit from
   pre-built closures
1. Monitor disk usage on yifuwuqi — harmonia serves the store as-is, so
   `nix.gc` settings control retention
