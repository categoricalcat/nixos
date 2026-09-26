---
name: etiquette
description: Agent work etiquette — the rules for where plans go, finding files with fd/rg, scratch scripts in /tmp/ai, and what agents never do (git commit/push, sudo, nixos-rebuild switch, raw ssh, reading secrets). Always active.
alwaysApply: true
---

## 1. Plans

- Every plan goes to `docs/src/plans/<topic>-plan.md` — that is the single plans folder; no plans anywhere else. One home for every plan keeps the code tidy.
- Follow the format: Objective / Current state / Decisions / Phases / Rollout order / Open questions.
- `.cursor/plans/` is ephemeral tool output, not a place for plans — a scrap of paper, not the writing desk.

## 2. Git

- Never run `git commit` or `git push` — that final click is the user's to keep.
- Leave changes in the working tree for the user to review and commit.
- Read-only inspection (`git status`, `git diff`) is always fine — look, but don't take.

## 3. System changes

- Never run `sudo` or any privilege escalation; root belongs to the user alone.
- Never run `nixos-rebuild switch`/`boot`, `nix switch`, or remote `nixos-rebuild --target-host`/`--build-host`.
- Instead: make the configuration changes with care, then hand the user the exact command to run. The machine changes hands gently.

## 4. Remote access

- Never raw `ssh`, `scp`, `sshfs`, `mosh`, `rsync` — don't reach across machines uninvited.
- The sanctioned lane is `ai-ssh <host> <command>` (read-only gate, see `docs/src/services/ai-ssh.md`).
- `ai-ssh` is deployed mesh-wide — read-only, server-gated; use it for every cross-host read, no invitation needed.

## 5. Secrets

- Never run `sops`, never decrypt or read secrets, keys, or tokens — what is locked stays locked.
- That includes `secrets/secrets.yaml`, sops-encrypted files, SSH/age key material, `~/.ssh/`, `/persist/keys/`.
- Reference secrets by path only, never by content; never print or commit them. Trust is built by what we refuse to look at.

## 6. Finding files and folders

- Always use `fd` or `rg` to find folders and files — `fd <pattern>` for paths/directories and `rg` (ripgrep) for searching content or listing files (`rg --files`).
- Avoid slow, noisy traversal tools like legacy `find`, `grep -r`, or recursive `ls`.
- Both `fd` and `rg` respect `.gitignore` and keep discovery swift — swift eyes see clearly without rummaging.

## 7. Scratch scripts and probes

- Never run rapid-fire inline one-liners (`python3 -c "..."`, nested shell loops, or ad-hoc test snippets) chained directly across tool calls.
- **Name after the session**: Each session maintains a single dedicated scratch file in `/tmp/ai/` named after the session or conversation ID (e.g. `/tmp/ai/<session-id>.<ext>`) to prevent collisions between concurrent sessions.
- **Edit in place**: Reuse and edit only this one file for probes, tests, and experiments throughout the session. Never litter `/tmp/ai/` with multiple files. Only create an additional file if the primary scratch file grows too large to process or compute as a whole.
- **No manual deletion needed**: Do not delete the scratch file after execution; it is persisted in `/tmp/ai/` for review and inspection, and automatically recycled by systemd-tmpfiles aging policies.
- Execute the scratch file deliberately, inspect the result, and ensure background tasks or hanging processes are prevented.
