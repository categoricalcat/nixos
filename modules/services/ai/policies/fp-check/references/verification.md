# Deterministic Verification for Generated Code and Proofs

Use this reference for implementation, review, property testing, formal specification, and proof-assistant work.

## Evidence ladder

| Label                   | What it supports                                             | What it does not establish                                                     |
| ----------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Generated               | An artifact was produced                                     | That it parses, compiles, or behaves correctly                                 |
| Compiled / type-checked | The artifact satisfies the toolchain's static checks         | Functional correctness or totality unless specifically encoded                 |
| Example-tested          | Selected executions matched expectations                     | Behavior on untested inputs                                                    |
| Property-tested         | Generated cases found no counterexample to stated properties | A universal proof; coverage depends on generators and properties               |
| Formally verified       | A checker accepted a proof of a stated formal proposition    | That the proposition matches intent, or that the entire trust base is flawless |

Name the actual level reached. “Verified by tests” is ambiguous; say exactly which tests or proof checks ran.

## Generate–check–repair loop

1. **Mine the existing contract.** Read public types, documentation, tests, call sites, protocol definitions, and nearby implementations. Preserve error and effect semantics.
1. **Write the smallest useful specification.** Use preconditions, postconditions, invariants, round trips, algebraic laws, or metamorphic relations. Include security- and privacy-relevant behavior when relevant.
1. **Constrain generation.** Require a complete artifact without hidden placeholders.
1. **Run the project's own checks,** including law checks and proof kernels, with its locked dependencies. Add tools only when needed and permitted.
1. **Diagnose the first relevant failure.** Distinguish implementation errors, generator gaps, incorrect tests, ambiguous specifications, and impossible requirements.
1. **Make one focused repair.** Rerun the failed check and then the relevant regression suite.
1. **Report** with the result pattern below.

Stop and explain the conflict if the requested behavior is inconsistent. Never manufacture success by weakening the contract: do not weaken a theorem, delete a test, or relax a specification to make a check pass.

## Choose useful properties

Prefer properties that would catch realistic defects:

- **Round trip:** `decode(encode(x)) = x` when the format promises it; otherwise state the actual canonicalization law.
- **Metamorphic relation:** a change that should not matter leaves output unchanged, or changes it predictably.
- **Invariant:** balances, ordering, bounds, ownership, or protocol states remain valid.
- **Algebraic law:** identity, associativity, commutativity, distributivity, functor laws, or monad laws when claimed.
- **Model agreement:** an optimized implementation agrees with a small, obviously simple reference model.
- **Idempotence or replay:** repeating an operation has the specified effect.

Include generators for empty, boundary, malformed, and adversarial inputs. A property suite with a shallow generator is weak evidence.

## Functional programming notes

- Exploit purity for local reasoning, but still specify the intended result.
- Move effects to explicit boundaries where useful; test or model state, concurrency, retries, and partial failures rather than pretending types remove them.
- Treat strong types as part of the specification. Enrich types only when the added invariants justify their complexity.
- Account for nontermination and partial functions. If an idealized programming category ignores bottom-like behavior or other actual language semantics, state that assumption in rigorous claims.

## Proof hygiene

- Do not close goals by silently introducing `sorry`, `admit`, placeholders, postulates, new axioms, unsafe casts, or trust-me escape hatches. Syntax varies by language; inspect the project for equivalents.
- Do not remove legitimate domain axioms indiscriminately. Instead, list axioms and assumptions explicitly and distinguish them from unfinished proofs.
- Never generalize, specialize, or rename the theorem merely to make it easier unless the user agrees to the changed target.
- When automation fails, inspect the goal and available hypotheses. Try a smaller lemma, explicit induction, rewriting, or a changed proof decomposition before broad random search.
- After success, run the clean project check and search the changed artifacts for unfinished-proof markers.
- When relevant, identify the trust base: proof kernel or compiler, trusted libraries, axioms, code extraction, and the formal specification itself.

## Concise result pattern

Report:

1. **Target:** the specification, behavior, or proposition addressed.
1. **Artifact:** files or definitions changed.
1. **Evidence:** exact checks run, their outcomes, and the evidence-ladder label reached.
1. **Boundary:** assumptions, placeholders, untested behavior and effects, weak generators, external services, unverified components, and remaining failures.

For example, “Type-checked and passed 1,000 generated round-trip cases” is precise; “proven correct” is not, unless a formal proposition and checker are identified.
