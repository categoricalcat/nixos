# Category Theory for Mathematics and Code

Use this language-neutral reference to explain categorical concepts, solve problems, check laws, or apply categorical structure to software without conflating metaphors with mathematics. Use mathematical notation here; choose programming syntax only after identifying the user's target language.

## Reason from definitions to structure

For any claim, establish:

1. **Category:** What are the objects and morphisms? What are identity and composition?
1. **Typing:** Does every expression have well-formed source and target?
1. **Variance:** Is a construction covariant, contravariant, or invariant in each argument?
1. **Laws:** Which equations, naturality conditions, or universal properties are required?
1. **Assumptions:** Is the setting ordinary categories, enriched categories, higher categories, or an idealized programming category?

Then reason explicitly:

- Define notation before using it, and label each statement as a definition, intuition, example, lemma, or theorem.
- Use universal properties when they explain why a construction is canonical, not merely how it is built.
- Check functoriality, naturality, unit and multiplication laws, or commuting diagrams as applicable.
- Give a concrete example. When a general claim is false, give a counterexample and state the corrected claim instead of silently proving a different one.

Move between three views: a concrete example, the formal definition, and the structural reason the result matters. Do not substitute one for the others.

## High-value structures

| Structure                         | Central question                                                                        | Typical software connection                                               |
| --------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Category                          | What composes, and under which identities?                                              | Typed functions, processes, relations, schemas                            |
| Functor                           | Does a construction preserve identity and composition?                                  | Lawful structure-preserving mapping over option, result, list, or context |
| Natural transformation            | Does a conversion commute with the functorial action?                                   | A uniform conversion such as option-to-list                               |
| Product / coproduct               | Which universal comparison makes this canonical?                                        | Pairing and choice, with categorical caveats in real languages            |
| Exponential / adjunction          | Is there a bijection `Hom(F A, B) ≅ Hom(A, G B)` natural in `A` and `B`?                | Currying, `Hom(A × B, C) ≅ Hom(A, C^B)`, in a cartesian closed setting    |
| Monad                             | How do context-producing computations compose lawfully?                                 | Sequencing with context, effects, or failure                              |
| Initial algebra / final coalgebra | What is the canonical recursive construction, or the canonical observation of behavior? | Folds over inductive data; unfolds, streams, and coalgebraic behavior     |

A table entry is a bridge to investigate, not an automatic equivalence. Check the language's semantics and the claimed laws.

## Check laws explicitly

For a functor `F`:

```text
F(id_A)  = id_{F(A)}
F(g ∘ f) = F(g) ∘ F(f)
```

For a natural transformation `η : F ⇒ G` and a morphism `f : A → B`:

```text
η_B ∘ F(f) = G(f) ∘ η_A
```

For a monad `(T, η, μ)`:

```text
μ_A ∘ η_{T(A)} = id_{T(A)} = μ_A ∘ T(η_A)
μ_A ∘ μ_{T(A)} = μ_A ∘ T(μ_A)
```

Translate these laws into a programming language only after selecting that language. Do not infer monad structure from a similarly named sequencing operator or special syntax.

For products, coproducts, limits, colimits, or free constructions, state the **unique mediating morphism** and its equations. Giving only a data construction misses the universal property.

## Apply theory to code responsibly

1. **Start with the software problem**, not with a desire to use categorical vocabulary.
1. **Translate the structure into concrete types and operations**, and derive the laws they must satisfy before selecting syntax or naming a pattern. A similarly named method is not evidence of a lawful instance.
1. **Account for the language's semantics:** effects, exceptions, failure, strictness or laziness, nontermination, resource limits, and performance. Distinguish exact mathematical claims from analogies.
1. **Compare with the simplest idiomatic design**, especially when the abstraction has ergonomic or performance costs.
1. **Test or prove the laws** when practical, keeping property tests distinct from proofs.

For a design, cover: concrete problem → candidate structures → laws and trade-offs → recommended encoding → validation plan.

Keep these caveats in view:

- Parametricity can support some free theorems, but only under stated language assumptions.
- Not every type constructor is a functor, and not every container is a monad. Specify the action on morphisms or operations and verify the laws.
- Do not present category theory as a prerequisite for all functional programming or as proof that a design is good.

## Worked bridge: an option-like functor

Consider a construction `F` that represents either the presence or absence of a value. To treat it as a functor, specify how it acts on morphisms, then check the identity and composition equations above.

A candidate implementation may transform a present value and preserve absence, but that description alone does not prove functoriality. The useful design content is not the name “functor” by itself: it is that mapping preserves structure, mappings compose predictably, and general laws can be tested or proved instead of relying only on examples.

Translate this idea into option, optional, maybe, nullable, or another appropriate representation only when it matches the target language's actual semantics. Avoid conflating absence, nullability, errors, and empty collections merely because they admit similar operations.

## Teach without jargon stacking

- Match notation and depth to the user's background.
- For an explanation, cover: notation → intuition → formal statement → example or proof → a common confusion, or a software connection when it helps.
- Introduce a concrete example, abstract from it, then return to another example or application.
- Use a small commuting diagram when it replaces a confusing paragraph; define its arrows.
- Distinguish common confusions: a functor is not merely a container, a monad is not merely chaining, and an adjunction is not merely a pair of functions.
- For exercises, provide the requested solution or hints with enough reasoning to make the steps inspectable.
- When the user asks a philosophical question about AI and mathematics, connect it back to concrete roles: generation, specification, proof checking, abstraction choice, and discovery. Avoid predictions presented as certainty.
