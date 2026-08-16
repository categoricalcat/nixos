# Yirukou TUI Enablement Plan

## Objective

Make interactive CLI / Terminal UI (TUI) tooling (`starship`, `zellij`, `tmux`, `btop`, `bottom`, `fzf`, `zoxide`, `yazi`, `broot`, `lazygit`, `gitui`, `atuin`, `mcfly`, `direnv`) available on `yirukou` (the router) and decouple TUI utilities from the heavy developer toolchain (`ghc`, `cabal`, `nodejs`, `pnpm`, `typescript`, etc.).

## Current State

- `users/programs/tui.nix` configures all the interactive TUI utilities:
  - Prompt: `starship` (with themed styling)
  - Multiplexers: `zellij`, `tmux`
  - System monitors: `btop`, `bottom`
  - File / directory navigation: `fzf`, `zoxide`, `yazi`, `broot`
  - Version control TUI: `lazygit`, `gitui`
  - Shell history & environment: `atuin`, `mcfly`, `direnv`
- In `users/home/common.nix`, `../programs/tui.nix` is imported conditionally inside `lib.optionals developer [...]`.
- `developer` in `common.nix` defaults to `config.serverMode.developer` (which comes from `config.host.developer` in `modules/host.nix`).
- `config.host.developer` defaults to `config.host.desktopEnvironment != null` (which is `false` for headless machines).
- `yifuwuqi` (server) and `yichuang` (WSL) explicitly set `host.developer = true;`, but `yirukou` (router) does not.
- As a result, `yirukou` is currently the only host in the fleet that completely lacks TUI tools and starship prompt, making interactive administration and shell navigation cumbersome.
- Setting `host.developer = true` on `yirukou` is undesirable because it would also pull in heavy developer toolchains (GHC, cabal, HLS, bun, nodejs, pnpm, typescript, and agent skill realizations).

## Decisions

1. **Decouple TUI from Developer mode**:
   - Introduce a new `host.tui` boolean option in `modules/host.nix`, defaulting to `true`.
   - Pass `tui = config.host.tui;` through `modules/common.nix` (`home-manager.extraSpecialArgs`).
   - In `users/home/common.nix`, import `../programs/tui.nix` conditionally based on `tui` (`lib.optionals tui [ ../programs/tui.nix ]`), with `tui ? true` as a default.
   - Keep heavy toolchains (`ghc`, `bun`, `nodejs`, `pnpm`, `typescript`, `agentSkills`, `opencode.nix`, `vscode-theme.nix`, `neovim.nix`) under `developer`.

2. **Default Behavior**:
   - All hosts (`yixiaoqing`, `yitaishi`, `yifuwuqi`, `yirukou`, `yichuang`, and `homeConfigurations.yijia`) will have `tui = true` by default.
   - `yirukou` immediately gains the full TUI suite without bloating its closure with compiler toolchains.
   - Any future host can opt out with `host.tui = false` if needed.

## Phases

### Phase 1: Host & Home-Manager Option Plumbing
- [ ] Modify `modules/host.nix` to add `options.host.tui` with `default = true;` and `serverMode.tui = config.host.tui;`.
- [ ] Modify `modules/common.nix` to pass `tui = config.host.tui;` in `home-manager.extraSpecialArgs`.
- [ ] Update `flake.nix` `homeConfigurations.yijia.extraSpecialArgs` to include `tui = true;`.

### Phase 2: Decouple TUI in Home-Manager Common Configuration
- [ ] Modify `users/home/common.nix` to accept `tui ? true` and import `../programs/tui.nix` via `lib.optionals tui [ ../programs/tui.nix ]`.

### Phase 3: Flake & Host Evaluation Verification
- [ ] Run `nix eval` on all 5 hosts (`yirukou`, `yifuwuqi`, `yitaishi`, `yixiaoqing`, `yichuang`) and `homeConfigurations.yijia`.
- [ ] Verify `programs.starship.enable`, `programs.zellij.enable`, and `programs.zoxide.enable` evaluate to `true` on `yirukou`.
- [ ] Verify developer-only packages (`ghc`, `nodejs`, `pnpm`) remain excluded on `yirukou`.

## Rollout Order

1. Make edits to `modules/host.nix`, `modules/common.nix`, `flake.nix`, and `users/home/common.nix`.
2. Validate flake evaluation locally on `yifuwuqi`.
3. Provide the exact rebuild/test commands for the user to run or deploy.

## Open Questions

- None. Decoupling `tui` via `host.tui` provides clean separation of concerns without unwanted dependencies.
