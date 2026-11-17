// Repo-wide flat config, shipped inside the eslint-env derivation (the
// wrapper passes --config). Plugin imports resolve against this derivation's
// node_modules — the repo root never needs a node_modules.
// Prettier owns formatting (treefmt); eslint-config-prettier (last entry)
// keeps every ruleset above out of formatting's way.
import js from "@eslint/js";
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
  perfectionist.configs["recommended-natural"],
  prettierConfig,
];
