# Mango Monitor Focus & Multi-Monitor Overview Handoff Plan

## Objective

Permanently eliminate the out-of-tree patch [`packages/mango-monitor-focus.patch`](../../packages/mango-monitor-focus.patch) and its recurring rebase friction on `flake.lock` updates, while preserving:

1. **Click-to-focus window behavior (`sloppyfocus = 0`) with cursor-driven monitor tracking**: Moving the pointer across monitor boundaries immediately updates `server.selected_monitor` so that shortcuts and launchers target the screen under the cursor without requiring a window click.
1. **Synchronized multi-monitor overview**: Entering or exiting overview mode (`toggleoverview`, gestures, or hot corner) switches all active displays on multi-head workstations (`yitaishi`) simultaneously.
1. **Unified package evaluation**: Eliminate host-conditional branching in [`modules/desktop/mango.nix`](../../modules/desktop/mango.nix) (`patchedMango` on `yitaishi` vs `baseMango` on `yixiaoqing`).

______________________________________________________________________

## Current State

### 1. The Patch Anatomy

The current patch modifies two translation units in `mangowm/mango` with a minimal diff focusing strictly on two features:

- **`src/input/pointer.c` (Feature 1: Cursor-driven monitor tracking bugfix)**:
  Upstream gates active monitor updates behind `if (config.sloppyfocus)`:
  ```c
  if (config.sloppyfocus) {
      Monitor *oldmon = server.selected_monitor;
      server.selected_monitor = monitor_at_point(server.cursor->x, server.cursor->y);
      if (oldmon != server.selected_monitor)
          printstatus(IPC_WATCH_MONITOR | IPC_WATCH_ALL_MONITORS);
  }
  ```
  Because `sloppyfocus = 0;` is declared in [`users/programs/mango.nix`](../../users/programs/mango.nix) (for click-to-focus), moving the cursor across monitors leaves `server.selected_monitor` stuck on the prior monitor until a window or desktop surface is clicked. The patch removes this guard so monitor selection always follows the cursor.
- **`src/dispatch/bind.c` (Feature 2: Synchronized multi-monitor overview)**:
  Upstream extracted the per-monitor overview logic into `static void set_overview(const Arg *arg, bool enter)`. In upstream `toggle_overview`, it only calls `set_overview` on `server.selected_monitor`. On `yitaishi` (triple monitor: `DP-3`, `DP-1`, `HDMI-A-1`), triggering overview leaves the other two monitors untouched. The patch modifies `toggle_overview` directly to call `set_overview` across all enabled monitors in `server.monitors` without renaming functions or creating superfluous wrapper layers, restoring focus upon exit.

### 2. Upstream Pace & Maintenance Friction

- Upstream Mango is in active development on the `wl-only` branch:
  - On 2026-09-06 (commit `04ce8fff`), monolithic headers were split into `.c` files and `selmon` became `server.selected_monitor`.
  - On 2026-09-09 (commit `ce66b4b4`), upstream refactored `toggle_overview` by extracting `set_overview(arg, enter)` and adding `enter_overview`/`leave_overview`.
- The patch broke and had to be rebased **4 times in 10 days** (commits `0a5b95b`, `cc3507d`, `0c9fed1`, `6cf05dc`, and working tree rebase).
- Nix's standard `patches = [ ... ]` evaluates strictly with `patch -p1`, rejecting patches whenever upstream adjusts nearby lines.

### 3. Upstream Contribution Environment

- **AI Policy**: There is **no policy prohibiting AI-assisted contributions** in `mangowm/mango`.
- **Maintainer Style**: Primary maintainer `DreamMaoMao` is an self-described "unconstrained pragmatist". Review feedback across merged PRs (e.g. PR #1356) focuses strictly on:
  1. Concise, non-scattered logic.
  1. Formatting with `./format.sh` (`clang-format`).
  1. Commits squashed into a single commit before merge ([`.github/CONTRIBUTING.md`](../../.github/CONTRIBUTING.md)).
  1. Real-world verification (preventing regressions in edge cases like minimize states and floating dialogs).

______________________________________________________________________

## Decisions

### 1. Dual-Track Resolution Strategy

- **Primary (Permanent)**: Upstream two separate PRs to `mangowm/mango`.
  - **PR 1 (Bugfix)**: Decouple monitor selection tracking from `config.sloppyfocus`.
  - **PR 2 (Feature)**: Add multi-monitor overview synchronization via a configuration option or dispatcher argument.
- **Intermediate (Stopgap)**: If immediate relief from `nix flake update` failures is needed before PRs merge upstream, maintain a downstream Git branch on a GitHub fork (`categoricalcat/mango:wl-only-custom`) and point `inputs.mango.url` to it. Git 3-way rebasing prevents Nix build rejections.

### 2. Rejection of External Scripting / IPC (`mmsg`) Wrappers

- External IPC wrapping cannot replace this patch:
  1. **Monitor tracking**: Mango exposes no pointer-tracking IPC stream (`mmsg watch cursorpos` does not exist); continuous polling is impractical.
  1. **Overview lifecycle**: In Mango, clicking any client in overview mode automatically invokes internal C `toggle_overview` (`pointer.c:1177`). An external keybinding wrapper cannot intercept mouse clicks or jump-mode selections, leaving secondary displays permanently stuck in overview.
- In-compositor logic is strictly required.

______________________________________________________________________

## Phases

### Phase 1: Upstream PR 1 — Decouple Monitor Tracking from `sloppyfocus`

#### Code Changes (`mangowm/mango`)

- Modify `src/input/pointer.c` in `pointer_process_motion`:
  ```diff
  --- a/src/input/pointer.c
  +++ b/src/input/pointer.c
  @@ -666,11 +666,10 @@ void pointer_process_motion(...) {
   		wlr_idle_notifier_v1_notify_activity(server.idle_notifier, server.seat);
   
   		/* Update selected_monitor (even while dragging a window) */
  -		if (config.sloppyfocus) {
  -			Monitor *oldmon = server.selected_monitor;
  -			server.selected_monitor =
  -				monitor_at_point(server.cursor->x, server.cursor->y);
  -			if (oldmon != server.selected_monitor)
  -				printstatus(IPC_WATCH_MONITOR | IPC_WATCH_ALL_MONITORS);
  -		}
  +		Monitor *newmon = monitor_at_point(server.cursor->x, server.cursor->y);
  +		if (newmon && newmon != server.selected_monitor) {
  +			server.selected_monitor = newmon;
  +			printstatus(IPC_WATCH_MONITOR | IPC_WATCH_ALL_MONITORS);
  +		}
   	}
  ```
- Modify `src/input/tablet.c` in `tablet_tool_process_motion`:
  ```diff
  --- a/src/input/tablet.c
  +++ b/src/input/tablet.c
  @@ -241,7 +241,7 @@ void tablet_tool_process_motion(...) {
   	pointer_process_motion(0, NULL, 0, 0, 0, 0);
   
  -	if (config.sloppyfocus) {
  +	if (1) {
   		Monitor *oldmon = server.selected_monitor;
   		server.selected_monitor =
   			monitor_at_point(server.cursor->x, server.cursor->y);
  ```

#### PR Details

- **Title**: `fix(input): update selected_monitor on pointer motion regardless of sloppyfocus`
- **Description**:
  > `sloppyfocus` controls whether window client focus follows pointer hover. Currently, `selected_monitor` tracking is guarded behind `if (config.sloppyfocus)`.
  >
  > When a user disables sloppy focus (`sloppyfocus=0`) for click-to-focus window behavior, moving the pointer across displays does not update `selected_monitor`. Consequently, keyboard shortcuts (spawning terminals, app launchers, workspace navigation) continue targeting the previous monitor until a window on the new monitor is clicked.
  >
  > This patch uncouples `selected_monitor` cursor tracking from `sloppyfocus` while preserving click-to-focus for windows.

______________________________________________________________________

### Phase 2: Upstream PR 2 — Synchronized Multi-Monitor Overview

#### Code Changes (`mangowm/mango`)

- Add configuration parameter `overview_sync_monitors` (or dispatcher parameter `toggleoverview,all`):
  1. Declare `int32_t overview_sync_monitors;` in `include/mango/config/parse_config.h`.
  1. Parse `overview_sync_monitors` in `src/config/parse_config.c` (default `0`).
  1. In `src/dispatch/bind.c`, trigger all active outputs when `config.overview_sync_monitors` is set (leveraging upstream's `set_overview`, so no function splitting is needed):
     ```c
     void toggle_overview(const Arg *arg) {
     	if (!server.selected_monitor || server.grab_client)
     		return;
     	if (!config.overview_sync_monitors) {
     		set_overview(arg, !server.selected_monitor->isoverview);
     		return;
     	}
     	Monitor *m = NULL, *focus = server.selected_monitor;
     	Client *sel;
     	bool enter;

     	sel = focus->sel;
     	enter = !focus->isoverview;

     	set_overview(arg, enter);

     	wl_list_for_each(m, &server.monitors, link) {
     		if (m == focus || !m->wlr_output || !m->wlr_output->enabled)
     			continue;
     		if ((bool)m->isoverview == enter)
     			continue;
     		server.selected_monitor = m;
     		set_overview(&(Arg){0}, enter);
     	}

     	server.selected_monitor = focus;
     	if (!enter && sel && VISIBLEON(sel, focus))
     		client_focus(sel, 1);
     	else
     		client_focus(client_focus_top(focus), 1);
     }
     ```
  1. Document the setting in `docs/window-management/overview.md`.

#### PR Details

- **Title**: `feat(overview): add overview_sync_monitors configuration option`
- **Description**:
  > Adds `overview_sync_monitors` option to toggle overview mode synchronously across all active monitors on multi-head setups, keeping overview states unified.

______________________________________________________________________

### Phase 3: Intermediate Fork (Stopgap Workflow)

If `nix flake update` is needed before upstream merges both PRs:

1. Create a personal fork: `github.com/categoricalcat/mango`.
1. Branch `wl-only-custom` tracking `mangowm/mango:wl-only` with the two commits applied.
1. In [`flake.nix`](../../flake.nix):
   ```nix
   mango = {
     url = "github:categoricalcat/mango/wl-only-custom";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
1. Remove `packages/mango-monitor-focus.patch` immediately from the repository.

______________________________________________________________________

### Phase 4: NixOS Flake Cleanup (Post-Upstream / Fork)

Once upstreamed or moved to a fork:

1. **Delete file**: `rm packages/mango-monitor-focus.patch`.
1. **Refactor [`modules/desktop/mango.nix`](../../modules/desktop/mango.nix)**:
   ```nix
   let
     mangoPackage = inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.mango.overrideAttrs (old: {
       postInstall = (old.postInstall or "") + ''
         substituteInPlace $out/share/wayland-sessions/mango.desktop \
           --replace-fail "DesktopNames=mango;wlroots" \
           "DesktopNames=mango;wlroots;X-NIXOS-SYSTEMD-AWARE"
       '';
     });
   in
   {
     config = lib.mkIf (config.desktop.environment == "mango") {
       programs.mango.package = mangoPackage;
       # ...
     };
   }
   ```
1. **Update [`users/programs/mango.nix`](../../users/programs/mango.nix)**:
   Add `overview_sync_monitors = 1;` under `config` when using upstreamed configuration.

______________________________________________________________________

## Rollout Order

1. **Local Test**: Build and verify mango on `yitaishi` and `yixiaoqing` using `nix build .#nixosConfigurations.yitaishi.config.programs.mango.package`.
1. **Submit PR 1**: Submit the bugfix for pointer motion; this should be an easy, non-controversial merge.
1. **Submit PR 2**: Submit the multi-monitor overview option once PR 1 is evaluated or concurrently.
1. **Deploy NixOS Cleanup**: Once merged (or using the fork branch), remove the patch file, simplify `modules/desktop/mango.nix`, and test on `yitaishi`.

______________________________________________________________________

## Open Questions

1. **Upstream PR preferences**: Does the maintainer prefer `overview_sync_monitors = 1` in `config.conf`, or `toggleoverview,all` dispatcher syntax? (The config option is generally cleaner for users who always want synchronized overviews across keybinds, gestures, and hot corners).
1. **Immediate fork vs waiting**: Should we switch `flake.nix` to a personal branch immediately to avoid any friction on next week's flake updates, or maintain the local patch until upstream reviews the PRs?
