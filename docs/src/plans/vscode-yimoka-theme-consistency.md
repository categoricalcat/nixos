# VS Code Yimoka Theme Consistency Plan

This document outlines the changes needed to fix the VS Code Yimoka theme so its
syntax highlighting matches Neovim's `mini.base16` (which already looks good).
The goal is a small, maintainable token mapping that mirrors `mini.base16`
exactly instead of layering exceptions on top of Stylix's generic template.

## Problem Statement

`users/programs/vscode-theme.nix` keeps **all** of Stylix's VS Code
`tokenColors` (~550 lines) and then appends just 3 override rules plus a
semantic token table. This causes a general inconsistency with Neovim:

- Stylix template rules use non-standard base16 colors for many scopes (e.g.
  properties and fields are teal `base0D` instead of red `base08`, bold/italic
  markup is red `base08` instead of foreground `base05`).
- The 3 override rules only cover a subset of scope patterns, so gaps remain.
- The override layer conflicts with the template layer depending on TextMate
  scope specificity, producing unpredictable results across languages.

The reference implementation is `mini.base16` (nix store path
`vimplugin-mini.nvim-0.18.0/lua/mini/base16.lua`, lines 560–594), which Neovim
uses via Stylix.

## Design Decisions

1. **Keep Stylix UI colors** — The `colors` section of the theme template
   (workbench, sidebar, activity bar, terminal, tabs) is fine and stays as the
   base of the generated theme.
2. **Replace `tokenColors` entirely** — Drop the Stylix template's token rules
   and write a compact (~35-rule) mapping that follows `mini.base16`
   conventions. No more layering/overriding.
3. **Mirror `mini.base16` semantics** — Variables render as `base05` (white)
   because `mini.base16` overrides `Identifier` with `@variable = base05` and
   `@lsp.type.variable = base05` for treesitter/LSP. Classic `Identifier =
   base08` only applies as a fallback.
4. **Prefer semantic tokens** — Modern VS Code languages rely on semantic
   tokens; the semantic token table is the primary mapping and TextMate rules
   are the fallback for non-semantic contexts (CSS, HTML, Markdown, JSON, etc.).

## Color Mapping (mini.base16 → VS Code)

| VS Code element | mini.base16 group | Color |
|---|---|---|
| Comment | `Comment` | `base03` |
| Variable, parameter | `@variable` | `base05` |
| Property, member (fallback) | `Identifier` | `base08` |
| Keyword, storage modifier | `Keyword` | `base0E` |
| Function, method | `Function` | `base0D` |
| Class, type, interface, enum, namespace | `Type` | `base0A` |
| Struct | `Structure` | `base0E` |
| Number, constant, boolean, enumMember | `Constant` | `base09` |
| String | `String` | `base0B` |
| Operator | `Operator` | `base05` |
| Special, regexp, escape | `Special` | `base0C` |
| Delimiter, embedded, deprecated | `SpecialChar` | `base0F` |
| Tag, label, event | `Tag` / `Label` | `base0A` |
| Macro, exception, error, invalid | `Macro` | `base08` |
| Diff added / removed / changed | `diffAdded` / `diffRemoved` / `diffChanged` | `base0B` / `base08` / `base0E` |
| CSS property names | (support) | `base0D` |
| Markdown headings | `Title` / `markdownH*` | `base0D` |
| JSON keys | (property-name) | `base0D` |
| URL / link | `Underlined` | underline, `base05` |

## Required Changes

### `users/programs/vscode-theme.nix`

1. **Keep** `tpl.colors` (Stylix UI colors) and `tpl` as the base.
2. **Remove** the current three appended token override rules
   ("Nvim mini.base16 Variables / Properties / Operators").
3. **Replace** `tokenColors = tpl.tokenColors ++ [...]` with a self-contained
   list following the table above:
   - Comments (italic, `base03`)
   - Variables → `base05`; properties/fields → `base08` (fallback)
   - Keywords, storage, control → `base0E`
   - Functions, methods → `base0D`
   - Numbers, constants, booleans → `base09`
   - Strings, symbols → `base0B`
   - Types, classes, tags → `base0A`
   - Operators, punctuation → `base05`
   - Embedded, delimiters, deprecated → `base0F`
   - Regex, escape chars, CSS property names → `base0C`
   - Diff inserted/deleted/changed → `base0B`/`base08`/`base0E`
   - Markdown headings → `base0D`, bold/italic → `base05` styled
   - JSON keys → `base0D`
   - URL/link → underline
   - Invalid/illegal → `base08`; deprecated → `base0F`
4. **Update** `semanticTokenColors` to match `mini.base16`:
   - `struct` → `base0E` (currently `base0A`)
   - `namespace` → `base0A` (currently `base0E`)
   - `macro` → `base08` (currently `base09`)
   - `decorator` → `base0D` (currently `base08`)
   - add `boolean` → `base09`
   - add `label` → `base0A`
   - keep `variable`/`parameter` → `base05`, `property`/`member` → `base08`
5. Keep everything else (extension packaging, activation script, vsix
   building) untouched.

## Expected Outcome

- VS Code syntax highlighting matches Neovim's `mini.base16` look.
- Token/semantic color definitions shrink from ~600 lines of layering to a
  ~90-line self-contained mapping.
- No more conflicts between template rules and overrides; behavior is
  predictable per scope group.

## Verification

1. Rebuild the theme and reinstall the vsix (`nixos-rebuild switch`, the
   activation script handles all editors).
2. Open the same file in VS Code and Neovim side by side and compare:
   - variables (white), keywords (mauve), functions (teal), types (yellow)
   - properties/members (red), numbers (peach), strings (green)
   - comments (gray italic), operators (white)
3. Spot-check CSS, HTML, JSON, Markdown, and a language with rich semantic
   tokens (e.g. TypeScript or Rust).
4. Verify the UI chrome (sidebar, tabs, activity bar, terminal) is unchanged.
