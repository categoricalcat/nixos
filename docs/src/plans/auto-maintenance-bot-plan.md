# Incremental Auto-Maintenance Plan

Status: implemented; Forgejo Actions secrets and a manual canary remain.

## Objective

Maintain one reviewable pull request from `bot/auto-maintenance` to `develop`
without a separate NixOS service or publishing state machine.

Each scheduled or manual summon performs one pipeline:

```text
branch -> agent worktree diff -> diff-to-commit -> push
```

The branch itself records progress. Repeated summons append commits to the
current pull request until `yi` merges it. The next summon then starts a new
cycle.

## Lifecycle

After fetching all remote branches:

- **New cycle:** `bot/auto-maintenance` is missing, or
  `git diff origin/develop...origin/bot/auto-maintenance` is empty. Recreate the
  local bot branch from current `origin/develop`.
- **Continue:** the bot branch has a non-empty diff. Check it out at its remote
  tip and add one more maintenance commit.

The workflow invokes `nxd-agy` once with
[`ci/auto-maintenance-prompt.md`](../../../ci/auto-maintenance-prompt.md),
stages the resulting worktree, and calls the existing `diff-to-commit` helper.
An empty agent diff is a successful no-op.

The resulting commit is pushed normally, never force-pushed. A new cycle
creates the Forgejo pull request; continuation runs only update its branch.
Fast-forward-only merging makes the retained branch an ancestor of `develop`,
which produces the empty diff that starts the next cycle.

## Authentication and CI

The workflow receives two repository Actions secrets:

- `AGY_OAUTH_TOKEN`: full agy OAuth token-file contents;
- `AUTO_MAINTENANCE_TOKEN`: minimum-scope `write:repository` PAT belonging to
  the non-admin `auto-maintenance` collaborator.

The agy token is copied into a temporary home removed at job exit. Git and the
Forgejo API use the bot PAT only for publishing.

A dedicated PAT is necessary because Forgejo's automatic Actions token does
not emit workflow events for its own pushes. Bot-PAT pushes emit normal pull
request synchronization events, so the existing CI evaluates and builds every
increment.

Branch protection remains authoritative: the bot may update only its branch
and create pull requests; only `yi` can approve and merge `develop`.

## Implementation

- [`.forgejo/workflows/auto-maintenance.yml`](../../../.forgejo/workflows/auto-maintenance.yml):
  manual and twice-daily summons on the native runner.
- [`ci/auto-maintenance.sh`](../../../ci/auto-maintenance.sh): branch decision,
  one agent invocation, commit, push, and initial PR creation.
- [`nix/scripts/diff-to-commit.sh`](../../../nix/scripts/diff-to-commit.sh):
  existing commit-message and commit helper.
- [`packages/wrappers.nix`](../../../packages/wrappers.nix): existing
  `nxd-agy` and `diff-to-commit` commands deployed on the runner host.

## Rollout

1. Create the bot collaborator and PAT.
1. Add both Actions secrets.
1. Confirm fast-forward-only merging and `develop` branch protection.
1. Manually dispatch one summon and verify that it creates one commit and one
   pull request.
1. Dispatch again and verify that it appends a commit to the same pull request.
1. Merge, dispatch once more, and verify that a fresh cycle starts from current
   `develop`.
