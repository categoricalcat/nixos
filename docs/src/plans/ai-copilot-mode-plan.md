# AI Copilot Mode for Multi-Session Plan Execution

## Status: DRAFT — handoff for future policy work

## Objective

Define and codify a reusable **Copilot Mode** in the repository's canonical AI policies (`modules/services/ai/policies/` and `users/home/ai-policies.nix`) so that starting any session with `"we are running @<planfile>"` puts the agent into an interactive, step-by-step execution loop that tracks state across multiple sessions via Markdown checkboxes.

## Current state

- Canonical agent instructions live in `modules/services/ai/policies/<name>/body.md` and are generated into tool-specific rule/skill files (`.gemini/`, `.cursor/`, `.claude/`, `.agents/`, `.opencode/`) by `users/home/ai-policies.nix`.
- `modules/services/ai/policies/etiquette/body.md` (`## 1. Plans`) defines where plans live (`docs/src/plans/<topic>-plan.md`), their required sections (`Objective / Current state / Decisions / Phases / Rollout order / Open questions`), and plan retirement upon completion.
- However, `etiquette/body.md` does not yet specify how an agent should execute a multi-session plan interactively when the user invokes `"we are running @<planfile>"`.
- The protocol is currently piloted inline in `docs/src/plans/aset-love-migration-plan.md`.

## Decisions

1. **Session-start trigger (`"we are running @<planfile>"`)**: When the user opens a session with `"we are running @<planfile>"` (or references a plan file to resume work), the agent enters Copilot Mode for that plan.
1. **Three-part orientation briefing**: Immediately upon reading the referenced plan and checking `git status` / `git diff`, the agent reports:
   - **What we are doing**: The plan's overall objective and active phase.
   - **Where we are**: Completed `[x]` checkboxes, current working-tree modifications, and — if a user-owned step was last in flight — asking *"What did you do since last session, and did it succeed?"*
   - **Where we are going**: The immediate next unchecked `[ ]` step and the upcoming verification gate.
1. **Step ownership & single-gate pacing**:
   - Rollout steps use `- [ ]` checkboxes labeled by owner (`(AI)` vs. `(User)`).
   - **AI steps** (code edits, `nix eval`, `statix`, `deadnix`, read-only `ai-ssh` / `dig` / `curl` / `rg` probes): the agent executes the step, presents concrete evidence, and marks `- [x]` in the plan file.
   - **User steps** (external dashboards, `deploy .#<host>`, `nixos-rebuild`, `sops`, `git commit`): the agent never crosses a user boundary unverified. It prints exact instructions/commands for the single current step, stops, and asks what the user did and whether it succeeded before running post-step verification.
1. **Plan file as persistent cross-session state**: The `- [ ]` / `- [x]` checkboxes and `Status:` heading in `docs/src/plans/<topic>-plan.md` serve as the persistent state machine across sessions until the plan file is retired (deleted) in the final completion diff.

## Phases

### Phase 1 — Dogfood on Live Migration

Run the protocol during the multi-session execution of `docs/src/plans/aset-love-migration-plan.md` and note any ergonomics or handoff improvements needed.

### Phase 2 — Codify in Canonical AI Policies

Add the Copilot Mode protocol to the canonical policy sources (either as a sub-section of `## 1. Plans` in `modules/services/ai/policies/etiquette/body.md` or as a dedicated policy in `users/home/ai-policies.nix`).

### Phase 3 — Verify & Retire Plan

Evaluate the Nix configuration to ensure all generated agent policy files build cleanly, and delete `docs/src/plans/ai-copilot-mode-plan.md` in the completing change set.

## Rollout order

- [ ] **1.1** Complete or validate the interactive copilot workflow on `docs/src/plans/aset-love-migration-plan.md` (User + AI).
- [ ] **2.1** Decide whether Copilot Mode belongs in `modules/services/ai/policies/etiquette/body.md` (`## 1. Plans`) or as a standalone skill/rule in `users/home/ai-policies.nix` (User).
- [ ] **2.2** Implement the policy update in `modules/services/ai/policies/` (AI).
- [ ] **3.1** Verify evaluation (`nix flake check --no-build` / Home Manager build check) and audit `git diff` (AI).
- [ ] **3.2** Retire `docs/src/plans/ai-copilot-mode-plan.md` in the same change set (AI).

## Open questions

1. Should Copilot Mode be an always-on section inside `modules/services/ai/policies/etiquette/body.md` under `## 1. Plans` (zero extra skill loading), or a separate `copilot` entry in `users/home/ai-policies.nix`?
1. Should multi-session plans also keep a short `Current step:` pointer next to `## Status:`, or are the `- [x]` / `- [ ]` checkboxes alone sufficient?
