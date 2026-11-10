# Code Quality

Whenever you read, write, or review code, **proactively** apply these rules within the scope of your task. Do not wait to be asked.

## 1. Eliminate Duplication (DRY)

- **Detect**: Copy-pasted blocks, repeated data literals (magic numbers/strings), structural clones, repeated boilerplate.
- **Act**: Flag it, propose extracting (function/variable/module/template), explain trade-offs, never silently propagate.

## 2. Reduce Cyclomatic Complexity

- **Detect**: Deeply nested conditionals (>2 levels), long bodies (>50 lines), repeated branching structures, "god files" (>300 lines).
- **Act**: Prefer lookup tables over `if`/`else` chains, early returns/guard clauses over nesting, extract large blocks, ensure split files have a single purpose.

## 3. Core Principles

- **Single Source of Truth**: Define data once, reference everywhere.
- **Smallest diff**: Prefer refactorings touching fewest files.
- **No Representation Bouncing**: Stay in the native data structure / category (e.g. Map -> Map). Never convert `Map -> List of pairs -> Nested Lists -> Flat List -> Map` just to transform keys or take products. Use category-native combinators and applicatives.
- **Comment why, not what**: Document reasons for non-obvious abstractions.
- **No premature abstraction**: Extract or share only when there are 2+ concrete usages. This cuts both ways: don't extract a constant, lookup table, barrel, or base config until a second consumer exists, and inline any such indirection whose consumer count drops to one.
- **No intermediate indirection chains**: Never create linear dependency chains of local declarations (`A -> B -> C`) where an intermediate named constant, tuple, or helper has only a single consumer in the same scope. Inline single-consumer values directly into their consumption site.
- **Colocation over wrapper abstraction**: Keep composite data structures flat and explicit at call sites. Do not extract factory functions, option bags, or builder wrappers unless 3+ independent callers diverge in parameterization and would otherwise duplicate substantial branching logic.
- **No single-file folders**: Unless required by framework conventions (e.g. Next.js App Router, file-system routing, convention-based package entrypoints), do not place an isolated file in its own directory or create single-child folder chains (`a/b/c/file.ts`). Co-locate the file with its consumer until a second related file (test, style, or sibling) arrives.
- **Idempotence & depth bound ($d \\le 1$)**: Refactoring is an idempotent transformation ($R \\circ R = R$). Never perform secondary refactorings on helpers, constants, or types introduced during the current change set. Confine refactoring blast radius strictly to code directly touched by the explicit task.

## 4. Proposing Changes

When detecting issues: name the pattern, show a concrete diff, state the impact (lines saved, maintenance reduced), and use judgment for minor duplications.
