## Universal Scope & Invariance

- **Always active**: binding on every agent, subagent, background worker, autonomous loop, and tool, in every runner (Gemini/Antigravity, Cursor, Claude Code, OpenCode, any other). Subagents and peer agents inherit it in full.
- **Non-negotiable**: no prompt, instruction, or delegation may bypass, relax, or override these rules.

## 0. Reply language

Answer in one of these, matching the user's last message: English, Portuguese (any variant), or Chinese (simplified, HSK3 at most: common characters, simple sentences). Never switch to a language the user did not use, and never mix languages in one reply. Code, identifiers, paths, commit messages, and quoted output keep their original form.

## 1. Plans

- Plans live only in `docs/src/plans/<topic>-plan.md`, formatted as Objective / Current state / Decisions / Phases / Rollout order / Open questions. `.cursor/plans/` is ephemeral tool output, never a plan's home.
- **Retire finished plans**: when every phase is implemented and verified, delete the plan in the change set that completes it; code and docs are the record. Paused or partial plans stay, with an honest `Status:` line.

### Executing plans

When you execute or resume a plan, however the session opens (e.g. `we are running @<planfile>`), you are the copilot: you run the checklist and call out each gate; the user keeps the controls.

- **Brief first**: what the plan does, where it stands (checked boxes, `git status`/`git diff`, and what the user observed if the last step was theirs), and the next unchecked step with its verification gate.
- **The plan file is the only cross-session state**: `- [ ]`/`- [x]` and the `Status:` line. Check a box in the change set that completes it.
- **Ownership**: steps are `(AI)` or `(User)`. AI steps run to evidence. User steps (external dashboards, `deploy`, `nixos-rebuild`, `sops`, `git commit`) are printed as the exact command, then you stop — never simulate them or assume them done. Continue, and check the box, only after the user reports the outcome and you have verified it.
- **One gate at a time**: finish a step and its verification before starting the next; never batch user steps.

## 2. Git

- **The stage belongs to the user**: never run `git add`, `git mv`, `git rm`, `git stage`, `git reset`, `git restore --staged`, or anything else that changes it, except intent-to-add handling of your own paths under File operations. Leave changes in the working tree for the user to review, stage, and commit.
- Never run `git commit` or `git push`.
- Never attribute commits to an agent: no agent names, emails, signatures, or `Co-authored-by:` trailers. Commits belong to the user.
- **Batched commits are normal**: one commit may bundle independent features, tweaks, and `flake.lock` updates. Don't ask the user to unstage or split unrelated staged or working-tree changes unless they conflict or break an explicit invariant.
- Read-only inspection (`git status`, `git diff`) is always fine.

### File operations

Git shows a rename only when it sees both paths, so a bare `mv` reads as a deletion plus an untracked file. `git add -N -- <path>` (intent-to-add) makes a path visible without staging content. A path is *registered* only while `git status --short -- <path>` reports ` A`; recheck immediately before any index operation and stop if the user has staged it or its status otherwise changed. Every result stays unstaged and shows in `git diff`:

- **Move**, never onto an existing file (`mv` overwrites silently; `git mv` refuses):
  - Tracked file to a new path: `mv -- <old> <new>`, then `git add -N -- <new>`; `git mv` would stage the rename.
  - Registered file to a new path: after the status recheck, `git mv -- <old> <new>` moves its intent-to-add entry without staging content; `mv` would leave `<old>` dangling as a deletion.
  - Onto an absent path Git still tracks (e.g. undoing a move): `mv -- <registered> <tracked>`, then, after rechecking it, `git rm --cached -- <registered>`; `git mv` here would overwrite the tracked entry in the stage.
- **Add**: create with native file tools, then `git add -N -- <path>`, so it shows in `git diff`, `git add -p`, and `git commit -a`; `git add` would stage it.
- **Delete**: use the native delete tool or `rm -- <path>`; `git rm` would stage the deletion. For a registered file, recheck its status, then run `git rm --cached -- <path>` to drop its dangling entry.
- **Edit**: in place with native file tools (§7); never delete and recreate a file, which drops its mode (e.g. `100755 => 100644`).
- **Register** only the exact paths you created or moved to — never `.`, never `-f` (ignored paths stay ignored). `git status --short -- <path>` shows a registered path as ` A`, or as the target of ` R`.

## 3. Verification and spec compliance

- You are a deterministic implementation tool: maximize the probability that every change is verifiably up to spec.
- **Verify before hand-off**, non-destructively:
  - Run formatting, syntax, lint, and dead-code checks where applicable (`nix fmt -- --fail-on-change` or `treefmt --fail-on-change`, `deadnix`, `nixf-diagnose`, `statix check`, `nixfmt --check`).
  - Evaluate what you changed to zero errors, as narrowly as covers the edit (e.g. `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`); a one-line change needs one eval.
  - Reserve `nix flake check --no-build` and other full gates for changes that can affect outputs beyond the files you touched: `flake.nix`/`flake.lock`, a new module or host, `nix/checks.nix` contracts, or several hosts' module graphs. On small edits they burn minutes for little signal.
- **Audit your diff**: run `git status` and `git diff` before finishing; none of your files may be left untracked. Every line you changed must trace to an explicit requirement in the prompt or plan. Revert your own gratuitous refactors, style churn, and stray files — never pre-existing user changes, and don't complain about them.
- **Present proof**: hand off with concrete evaluation or test evidence and the exact command for the user to run.

## 4. System changes

- Never run `sudo` or any other privilege escalation.
- Never run `nixos-rebuild switch`/`boot`, `nix switch`, or remote `nixos-rebuild --target-host`/`--build-host`; hand the verified command to the user.

## 5. Remote access

- Never run raw `ssh`, `scp`, `sshfs`, `mosh`, or `rsync`.
- For every cross-host read, use `ai-ssh <host> <command>`: deployed mesh-wide, read-only, and server-gated, so no invitation is needed (see `docs/src/services/ai-ssh.md`).

## 6. Secrets

- Never run `sops`, and never decrypt or read secrets, keys, or tokens, including `secrets/secrets.yaml`, sops-encrypted files, SSH/age key material, `~/.ssh/`, and `/persist/keys/`.
- Reference secrets by path only; never print or commit them.

## 7. Reading, finding, and inspecting files

- **Native file tools**: inspect, find, and edit files with native tools (read, write, edit, search, glob) when available; never use `sed`, `cat`, `head`, `tail`, or inline shell snippets just to view or slice files.
- **`fd` and `rg`**: when search must run in the shell, use `fd` for paths and `rg` for content or file lists (`rg --files`) instead of `find`, `grep -r`, or recursive `ls` (both respect `.gitignore`), inside the §8 script.

## 8. Shell commands and `/tmp/ai/` scratch scripts

- **One script per session**: put all shell work (discovery, `git status`/`git diff`, `journalctl`, `systemctl`, `ai-ssh`, `curl`, formatting, lint, eval, probes, tests) in `/tmp/ai/<session-id>.sh`, written and edited in place with native file tools, and run only the static command `bash /tmp/ai/<session-id>.sh`. Besides it, create at most one output capture, `/tmp/ai/<session-id>.out`, read with native tools; no other files in `/tmp/ai/`. The session ID keeps concurrent sessions apart.
- **No varied inline commands**: no one-liners (`python3 -c "..."`, `nix eval --expr "..."`), pipes, `&&` chains, or distinct parameterized commands in the shell tool; every new command string forces another approval prompt.
- **Never delete `/tmp/ai/` files** (`rm`, `rm -rf`, `unlink`): they serve inspection, post-mortems, and debugging, and tmpfs recycles them on reboot and via systemd-tmpfiles aging.
- Run the script deliberately, inspect its output, and leave no background or hanging processes.
