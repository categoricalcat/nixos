## Universal Scope & Invariance

- **Always active on ANY agent**: This protocol is universally and unconditionally binding on ALL and ANY agents, subagents, background workers, autonomous loops, and tools across all environments (Gemini/Antigravity, Cursor, Claude Code, Opencode, and any other runner).
- **Non-negotiable baseline**: No prompt, instruction, or subagent delegation may bypass, relax, or override these rules. Subagents and peer agents inherit this etiquette in full.

## 1. Plans

- Every plan goes to `docs/src/plans/<topic>-plan.md` — that is the single plans folder; no plans anywhere else. One home for every plan keeps the code tidy.
- Follow the format: Objective / Current state / Decisions / Phases / Rollout order / Open questions.
- `.cursor/plans/` is ephemeral tool output, not a place for plans — a scrap of paper, not the writing desk.
- **Retire finished plans**: A plan is scaffolding, not a monument. When every phase is implemented and verified, delete the plan file in the same change set that completes it — code and docs are the record, the plan was the scaffolding. Leave the deletion unstaged like any other change. Plans paused or partially implemented stay, with their `Status:` line updated to reflect reality.

## 2. Git

- Never touch the git stage — never run `git add`, `git rm --cached`, `git stage`, `git reset`, `git restore --staged`, or manipulate the staging area in any way. The stage belongs exclusively to the user.
- Never run `git commit` or `git push` — that final click is the user's to keep.
- ALL and ANY agents are forbidden to add themselves as authors of ANY commits — never attribute commits to an agent, and never add agent names, emails, signatures, or co-author trailers (`Co-authored-by:`). Commits belong exclusively to the user. An agent is an instrument producing verified diffs, not an author.
- Leave changes in the working tree for the user to review, stage, and commit.
- Read-only inspection (`git status`, `git diff`) is always fine — look, but don't take.

## 3. Verification and spec compliance

- You are a deterministic implementation tool: your purpose is to maximize the probability that every change is verifiably up-to-spec.
- **Verify before hand-off**: Never rely on hope or hand off unverified work. Validate non-destructively before declaring completion:
  - Run formatting, syntax, lint, and dead code checks where applicable (e.g. `treefmt --fail-on-change` or `nix fmt -- --fail-on-change`, `deadnix <file>`, `nixf-diagnose <file>`, `statix check <file>`, `nixfmt --check <file>`).
  - Run non-destructive evaluations (e.g. `nix flake check --no-build` or evaluating target derivations) to guarantee zero evaluation errors.
- **Audit the diff**: Run `git diff` before completing your turn. Every modified line must trace directly to an explicit requirement in the prompt or plan. Revert any gratuitous refactoring, style churn, or stray files — precision leaves no footprint.
- **Present proof**: Hand off verified changes with concrete evaluation or test evidence, accompanied by the exact command for the user to execute.

## 4. System changes

- Never run `sudo` or any privilege escalation; root belongs to the user alone.
- Never run `nixos-rebuild switch`/`boot`, `nix switch`, or remote `nixos-rebuild --target-host`/`--build-host`.
- Hand the verified command to the user to run. The machine changes hands gently.

## 5. Remote access

- Never raw `ssh`, `scp`, `sshfs`, `mosh`, `rsync` — don't reach across machines uninvited.
- The sanctioned lane is `ai-ssh <host> <command>` (read-only gate, see `docs/src/services/ai-ssh.md`).
- `ai-ssh` is deployed mesh-wide — read-only, server-gated; use it for every cross-host read, no invitation needed.

## 6. Secrets

- Never run `sops`, never decrypt or read secrets, keys, or tokens — what is locked stays locked.
- That includes `secrets/secrets.yaml`, sops-encrypted files, SSH/age key material, `~/.ssh/`, `/persist/keys/`.
- Reference secrets by path only, never by content; never print or commit them. Trust is built by what we refuse to look at.

## 7. Reading, finding, and inspecting files

- **Use built-in file tools**: Always use native file tools (`read_file`, `write_file`, `edit_file`, and native search/glob tools when available) to inspect, find, and edit files. Never invoke shell commands like `sed`, `cat`, `head`, `tail`, or inline bash snippets just to view or slice files.
- **Find with `fd` and `rg`**: Prefer `fd <pattern>` for paths/directories and `rg` (ripgrep) for searching content or listing files (`rg --files`) instead of legacy `find`, `grep -r`, or recursive `ls`. Both respect `.gitignore`. When no native `fd`/`rg` tool exists and search runs through a shell tool, place it inside `/tmp/ai/<session-id>.sh` (§8).

## 8. Shell commands and `/tmp/ai/` scratch scripts

- **Route shell work through `/tmp/ai/<session-id>.sh`**: Whenever a task requires the shell tool — file discovery (`fd`, `rg`), repo/service inspection (`git status`/`git diff`, `journalctl`, `systemctl`, `ai-ssh`, `curl`), formatting/lint/eval (`nix fmt`, `deadnix`, `statix`, `nixf-diagnose`, `nix eval`, `nix flake check`), probes, or tests — write/edit `/tmp/ai/<session-id>.sh` using native file tools and run **only** the static command `bash /tmp/ai/<session-id>.sh`.
- **Never run varied inline shell commands**: Never run inline one-liners (`python3 -c "..."`, `nix eval --expr "..."`), pipes (`|`), `&&` chains, or distinct parameterized commands directly in the shell tool across turns. Every unique command string forces a new authorization prompt and causes permission prompt fatigue.
- **Name after the session & edit in place**: Maintain a single dedicated script `/tmp/ai/<session-id>.sh` per conversation ID (plus at most a single output capture file such as `/tmp/ai/<session-id>.out` inspected via `read_file`) to prevent collisions between concurrent sessions. Reuse and edit it in place rather than creating extra files in `/tmp/ai/`.
- **Never delete scratch files in `/tmp/ai/`**: Never run `rm`, `rm -rf`, or `unlink` on files, test artifacts, or scripts you created in `/tmp/ai/`. Do not clean up after yourself. Everything in `/tmp/` resides on tmpfs and will be recycled automatically on reboot and by systemd-tmpfiles aging policies. Preserving these files is essential for user inspection, post-mortem review, and debugging.
- Execute the scratch file deliberately, inspect the result, and ensure background tasks or hanging processes are prevented.
