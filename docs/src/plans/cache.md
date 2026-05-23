# CI & Cache Infrastructure Plan

## Objective
To enable full NixOS closure building in CI without hitting GitHub Actions disk space limits, we will transition to a hybrid CI setup using our self-hosted runner `yifuwuqi` for building and serving an Attic binary cache. 

To maintain security for a public repository, untrusted code (Pull Requests) will remain restricted to lightweight evaluation on GitHub's disposable runners.

---

## 1. CI Workflow Separation

We will split the monolithic `flake-ci.yml` into two distinct, purpose-built workflows.

### PR Validation Workflow (`.github/workflows/pr-validation.yml`)
- **Trigger:** `pull_request` to `main` and `develop`
- **Environment:** GitHub-hosted runners (`ubuntu-latest`)
- **Purpose:** Safe validation of untrusted code from external contributors.
- **Actions:**
  - `nix fmt -- --ci`
  - `nix flake check`
  - `nix eval` (ensures the configuration evaluates successfully for all hosts)
- **Security:** No secrets or internal network access is provided to this runner.

### Post-Merge Build Workflow (`.github/workflows/build.yml`)
- **Trigger:** `push` to `main` and `develop`
- **Environment:** Self-hosted runner (`runs-on: self-hosted`) on `yifuwuqi`
- **Purpose:** Building the actual derivations and pushing them to the cache.
- **Actions:**
  - Evaluate matrix of hosts.
  - `nix build .#nixosConfigurations.${{ matrix.host }}.config.system.build.toplevel`
  - Push resulting closures to the self-hosted Attic cache.
- **Security:** This only runs after code has been reviewed and merged by a maintainer, making it safe to execute on the internal network.

---

## 2. Enabling the Self-Hosted Runner
We already have the configuration for the runner in `modules/services/github-runner.nix`.
- Enable the module in `hosts/yifuwuqi/services.nix` by uncommenting the import.
- Ensure the token secret (`tokens/github-runner-nixos`) is properly provisioned via sops-nix.

---

## 3. Self-Hosted Binary Cache (Attic)

To allow the rest of the fleet to benefit from the CI builds, `yifuwuqi` will run an Attic server. Attic is a Nix binary cache server with deduplication and garbage collection.

### Setup on yifuwuqi
1. **NixOS Module:** Add the `services.atticd` configuration to `yifuwuqi`.
2. **Storage:** Configure local storage on `yifuwuqi` for the cache chunks.
3. **Database:** Attic uses PostgreSQL or SQLite; we will likely use PostgreSQL for better performance with multiple hosts.
4. **Proxy:** Expose Atticd via the existing Nginx reverse proxy (likely internal to the Tailnet).

### Client Configuration
1. **Cache URL:** Add the Attic URL to `nix.settings.substituters` in the global NixOS configuration.
2. **Public Key:** Add the Attic server's public key to `nix.settings.trusted-public-keys` so other hosts accept the signatures.

### Workflow Integration
1. The `build.yml` workflow will need the `attic-client` package.
2. The workflow will use an Attic authentication token (managed via GitHub Secrets or sops) to run `attic push default <path>` after successful builds.

---

## Next Steps for Implementation
1.  **Phase 1:** Write the NixOS configuration for Attic on `yifuwuqi` and deploy it.
2.  **Phase 2:** Uncomment the `github-runner` module on `yifuwuqi` and verify it connects to GitHub.
3.  **Phase 3:** Create the split GitHub Actions workflows and test the CI pipeline.
