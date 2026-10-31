# Optional Haskell Reference

Use this reference only when Haskell is the target language or a concrete Haskell encoding would materially clarify an idea. Haskell is a useful reference because its type constructors, higher-kinded abstractions, and equational style expose many categorical patterns directly.

## Reference points

- Use `Functor`, `Applicative`, and `Monad` as interfaces with laws, not merely as names for reusable type classes.
- A polymorphic function `forall a. f a -> g a` between lawful `Functor`s is natural by parametricity, assuming no `seq`, bottom, or unsafe escapes. State that assumption, or property-test the naturality law.
- Use products, sums, and function types as useful intuition for categorical constructions, while accounting for Haskell's actual semantics.
- Prefer ordinary Haskell APIs and naming unless categorical vocabulary improves communication with the intended audience.

## Express laws idiomatically

Functor laws:

```haskell
fmap id = id
fmap (g . f) = fmap g . fmap f
```

Monad laws expressed with `return` and sequencing:

```haskell
return a >>= f = f a
m >>= return = m
(m >>= f) >>= g = m >>= (\x -> f x >>= g)
```

For a candidate natural transformation such as `safeHead` from lists to optional values, check the appropriate naturality equation:

```haskell
safeHead . fmap f = fmap f . safeHead
```

These equations state intended laws; the compiler does not generally prove them for instances. Use property-based tests for useful evidence and a formal system when a proof is required. Keep those evidence levels distinct.

## State Haskell-specific caveats

- Treat `Hask` as an idealization when doing categorical reasoning. Haskell values can involve nontermination and bottom-like behavior.
- Account for strictness, laziness, exceptions, and observational distinctions when they affect the claimed equations.
- Do not use unsafe escape hatches to make a law appear true.
- Do not assume every type constructor has a lawful `Functor` instance or every type with sequencing has a lawful `Monad` instance.
- Do not claim that passing type-class constraints establishes category-theoretic laws.

## Translate away from Haskell by meaning

When the user's language differs, translate the **operations, laws, effects, and semantic caveats**, not Haskell syntax. Choose that language's own representation for absence, failure, sequencing, polymorphism, and composition. If the language cannot express the same abstraction directly, use a simpler design or a property-level specification rather than a forced imitation.
