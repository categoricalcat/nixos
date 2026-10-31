# Verified Functional Programming and Category Theory

Connect probabilistic generation with deterministic checking, and connect mathematical structure with idiomatic software. Support both conceptual understanding and executable artifacts without overstating what either mathematics or verification establishes.

## Core rules

- Proofs and mathematical explanations need checking just as code does: treat generated ones as unchecked proposals until verified.
- Separate **generated**, **compiled**, **example-tested**, **property-tested**, and **formally verified**. Never use these labels interchangeably.
- State the specification, assumptions, and trust base behind any correctness claim. A proof establishes a formal proposition, not automatically the user's intent.
- Do not equate determinism, purity, strong types, or mathematical elegance with correctness. Use them to make reasoning and checking easier.
- Use category theory only when it clarifies structure, laws, composition, or design. Provide an idiomatic non-categorical alternative when jargon would add cost without insight.
- Keep general guidance language-neutral. Use the user's language and idioms rather than Haskell-shaped pseudocode; treat Haskell as an optional reference encoding, not the default output language or the only categorical setting.

## Route the task

- **Explain or solve category theory:** read [references/category-theory.md](references/category-theory.md).
- **Generate, review, or repair code or proofs:** read [references/verification.md](references/verification.md).
- **Connect category theory to software:** read both references; establish the mathematical laws first, then choose an encoding and verification level.
- **Use Haskell as a concrete reference:** read [references/haskell.md](references/haskell.md) only when Haskell is the target or a Haskell example would materially help.

## Shared workflow

1. **Identify the deliverable.** Determine whether the user needs an explanation, proof, design, implementation, refactor, review, or repaired artifact. Inspect existing project conventions before choosing tools or notation.
1. **Make the target precise.** For mathematics, state the claim, definitions, and assumptions. For software, state inputs, outputs, effects, failure behavior, invariants, and compatibility constraints. Ask when ambiguity materially changes the result; otherwise proceed with explicit assumptions.
1. **Choose proportionate rigor.** Select the weakest assurance level that meets the need: clear explanation, type checking, examples, property tests, or formal proof. Do not impose a proof assistant on an ordinary coding task without a reason.
1. **Check, repair, and report.** For code and proofs, follow the generate–check–repair loop and result pattern in [references/verification.md](references/verification.md). For mathematics, check laws and diagrams by explicit reasoning as described in [references/category-theory.md](references/category-theory.md). Treat their checklists as coverage guidance adapted to the user's level and requested format, not as mandatory headings.
