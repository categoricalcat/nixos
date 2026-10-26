# Incremental auto-maintenance

Work directly in the current repository checkout and produce one coherent,
reviewable maintenance diff. Do not stage, commit, push, or create a pull
request; the caller owns those operations.

The caller appends each summon to the same maintenance pull request until it is
merged:

- For `CYCLE: new`, begin a fresh maintenance cycle from `develop`. Update
  `flake.lock`, run the relevant checks, and fix one concrete issue if the
  update exposes one.
- For `CYCLE: continue`, inspect the existing branch relative to
  `origin/develop`, run the relevant checks, and address the highest-priority
  remaining failure or incomplete maintenance item.
- If the branch is already green, make at most one small, clearly beneficial
  cleanup instead of inventing work.
- Preserve unrelated behavior and existing user changes.
- Leave the tree unchanged when there is no justified improvement.
