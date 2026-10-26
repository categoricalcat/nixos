# Auto-Maintenance

Forgejo Actions incrementally maintains one pull request from
`bot/auto-maintenance` to `develop`. Each summon asks `nxd-agy` for one
reviewable change, hands the staged diff to `diff-to-commit`, and pushes the
result.

The workflow runs manually or at 05:30 and 17:30 UTC (02:30 and 14:30 in
`America/Sao_Paulo`).

## Branch lifecycle

The remote branch is the only persistent state:

1. Fetch `develop` and `bot/auto-maintenance`.
1. Start a new cycle when the bot branch is absent or has an empty three-dot
   diff against `develop`.
1. Otherwise, check out the bot branch and continue its existing pull request.
1. Run the agent once, stage its diff, and create one commit with
   `diff-to-commit`.
1. Push normally without force.
1. Create a pull request only for a new cycle. Later summons add commits to the
   existing pull request automatically.

With fast-forward-only merges, the retained bot branch becomes an ancestor of
`develop`; its three-dot diff is then empty, so the next summon starts the next
cycle from current `develop`.

If the agent produces no diff, the workflow exits successfully without a
commit, push, or pull request.

## Forgejo setup

Create a non-admin `auto-maintenance` user, add it to `yi/nixos` as a Write
collaborator, and create a minimum-scope `write:repository` token. Keep
`develop` protected so only `yi` can push or merge, with required approval and
CI.

Configure these repository Actions secrets:

| Secret                   | Value                                                                          |
| ------------------------ | ------------------------------------------------------------------------------ |
| `AGY_OAUTH_TOKEN`        | Complete contents of `antigravity-oauth-token` from a temporary agy login home |
| `AUTO_MAINTENANCE_TOKEN` | PAT for the `auto-maintenance` Forgejo user                                    |

Use the dedicated PAT for publishing. Forgejo deliberately suppresses workflow
events caused by its automatic Actions token, whereas bot-PAT pushes trigger
the pull request's normal CI.

The native runner host must expose `nxd-agy` and `diff-to-commit`; both are
already installed by `modules/packages`.

## Operation

Run **Actions → Auto Maintenance → Run workflow** for an immediate summon.
Scheduled and manual runs share one non-cancelling concurrency group.

Review the accumulated commits and CI in the pull request. Merge when the
maintenance cycle is complete. The bot never merges.

If initial push succeeds but pull-request creation fails, create the PR
manually from `bot/auto-maintenance` to `develop`; later summons will continue
that branch. To abandon a cycle, delete the bot branch so the next summon starts
from current `develop`.
