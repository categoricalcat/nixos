# Auto-maintenance repair

`/work` is a plain copy of `develop` (no git metadata) whose `flake.lock` the
caller has just refreshed with `nix flake update`. You are summoned only because
`nix flake check --no-build` or `nix-fast-build --flake .#hydraJobs` failed on
it; the failure log is attached below. The caller commits and publishes
whatever you leave in `/work`.

- Repair that failure with the smallest possible diff: the broken package,
  module option, overlay, or check.
- Do not edit `.forgejo/`, `.gitea/`, `.github/`, `ci/`, or `nix/scripts/`; the
  caller rejects any change there.
- Do not perform unrelated cleanups, formatting churn, or opportunistic
  refactoring, and leave no scratch files behind.
- Re-run the failing `nix eval`, `nix build`, or `nix flake check --no-build`
  target to confirm the repair before finishing.
- Preserve existing behavior and user configuration.
