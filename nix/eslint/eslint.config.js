// Repo-wide flat config, shipped inside the eslint-env derivation (the
// wrapper passes --config). Plugin imports resolve against this derivation's
// node_modules — the repo root never needs a node_modules.
// treefmt runs Prettier, then `eslint --fix`. eslint-config-prettier (last
// entry) keeps the rulesets above out of Prettier's way; what eslint still
// fixes (block padding, import order) is applied by `nix fmt`.
import js from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";
import prettierConfig from "eslint-config-prettier";
import perfectionist from "eslint-plugin-perfectionist";
import unicorn from "eslint-plugin-unicorn";
import globals from "globals";
import tseslint from "typescript-eslint";

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  unicorn.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      globals: { ...globals.browser },
    },
  },
  {
    // null is load-bearing: JSON-RPC encodes it on the wire, and DOM APIs
    // (querySelector, getElementById) return it.
    rules: {
      "unicorn/no-null": "off",
    },
  },
  // The @stylistic recommended preset (registers the plugin too). Prettier
  // owns formatting (treefmt), so prettierConfig (last entry) strips every
  // formatting rule in the preset; what survives is the non-formatting core
  // (spaced-comment, lines-between-class-members, ...) plus the padding rule
  // below, which the preset omits.
  stylistic.configs.recommended,
  {
    rules: {
      // Fights Prettier on trailing-comma wraps (eslint-config-prettier
      // predates the rule): Prettier breaks before `)`, list-style forbids
      // it. Prettier wins.
      "@stylistic/list-style": "off",
      // Blank lines around multiline blocks; single-line guard clauses
      // (if (...) throw ...) stay dense. Prettier-safe: eslint-config-prettier
      // never touches this rule and Prettier keeps single blank lines.
      "@stylistic/padding-line-between-statements": [
        "error",
        { blankLine: "always", next: "multiline-block-like", prev: "*" },
        { blankLine: "always", next: "*", prev: "multiline-block-like" },
      ],
    },
  },
  perfectionist.configs["recommended-natural"],
  prettierConfig,
];
