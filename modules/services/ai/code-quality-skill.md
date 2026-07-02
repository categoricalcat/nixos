---
name: code-quality
description: Proactively detect and refactor duplicated code and cyclomatic complexity. Always active, language-agnostic.
alwaysApply: true
---

# Code Quality

Whenever you read, write, or review code, **proactively** apply these rules. Do not wait to be asked.

## 1. Eliminate Duplication (DRY)

- **Detect**: Copy-pasted blocks, repeated data literals (magic numbers/strings), structural clones, repeated boilerplate.
- **Act**: Flag it, propose extracting (function/variable/module/template), explain trade-offs, never silently propagate.

## 2. Reduce Cyclomatic Complexity

- **Detect**: Deeply nested conditionals (>2 levels), long bodies (>50 lines), repeated branching structures, "god files" (>300 lines).
- **Act**: Prefer lookup tables over `if`/`else` chains, early returns/guard clauses over nesting, extract large blocks, ensure split files have a single purpose.

## 3. Core Principles

- **Single Source of Truth**: Define data once, reference everywhere.
- **Smallest diff**: Prefer refactorings touching fewest files.
- **Comment why, not what**: Document reasons for non-obvious abstractions.
- **No premature abstraction**: Extract only when there are 2+ concrete instances.

## 4. Proposing Changes

When detecting issues: name the pattern, show a concrete diff, state the impact (lines saved, maintenance reduced), and use judgment for minor duplications.
