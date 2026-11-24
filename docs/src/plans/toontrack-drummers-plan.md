# Toontrack EZdrummer 3 / Superior Drummer 3 in REAPER (Wine + yabridge)

## Status: DRAFT — plumbing lands and builds (verified 2026-11-24: the four launcher packages build, `yabridgectl` config carries both prefixes). Step 1 (EZD3 trial) is the active phase; target decision pending (EZD3 / SD3 / both).

## Objective

Get Toontrack drums running in REAPER on `yitaishi` (Windows-only products → Wine + yabridge, mirroring `modules/audio/amplitube.nix`), in 2 steps:

1. **Step 1 — demo**: a working derivation for the **EZdrummer 3 10-day trial** (fully functional; there is no SD3 trial). Proves the whole pipeline end-to-end (prefix, installer under Wine, FAudio, yabridge sync, X11 REAPER) and yields usable drums while the pirate target is decided.
1. **Step 2 — crack**: install the CE-V.R cracked EZD3/SD3 (installers under Wine + libraries) so it runs indefinitely with no trial / Product Manager.

## Current state

### Verified

- REAPER runs natively on `yitaishi` (niri Wayland + DMS) via the `nix/overlays.nix` overlay (patchelf fix, `pipewire.jack`, `LC_NUMERIC=C`).
- Locked nixpkgs `nixos-26.11pre1125864.2786a2a` (rev `2786a2a7...`): yabridge **5.1.1** (stub built against `wineWow64Packages.yabridge` = **wine-staging 9.21, wow64**; the stub's `WINELOADER` is hard-coded to that wine binary), wine stable **11.0**, wine staging **11.21**, gecko 2.47.4, mono 10.4.1.
- **PM download pipeline** (verified 2026-11-24, scratch at `/tmp/ai/toontrack-probe.sh`): the site's `TT_TRY_MODAL` nonce (currently `4130e67027`) → `GET https://www.toontrack.com/wp-json/toontrack/v1/user-area/download/url/7115` with an `X-WP-Nonce` header → signed `hwsecure.toontrack.com` URL (hmac rotates per request; `st`/`exp` are ~1 year apart). PM WIN zip: 15,910,694 B, sha256 `550291ac2c4cca2068848a4d2aa7fed5cd9f142ac93638853b1dab2b86c88aed`, byte-identical across fetches. **A captured URL does not survive**: the one recorded during the probe answers `403` (Akamai `edgesuite`), and the ACL-token form is `?__token__=st=…~exp=…~acl=…~hmac=…`, not the `?sig=` shape the probe printed. Conclusion: the zip is fetched by the user, never by Nix.
- **`fetchzip` cannot take the signed URL even when it is live**: `baseNameOf` keeps the query string, so the download lands as `…zip*~hmac=…` with no `.zip` suffix and the unzip hook never matches (`do not know how to unpack`, reproduced against a local server). `extension = "zip"` fixes it, but the URL-expiry problem above makes that moot.
- **file-id 7114** (present on the EZD3 product page) = `Toontrack_Product_Manager_MAC.dmg` (25,586,436 B) — **not** a direct EZD3 trial download → the trial is only obtainable through the Product Manager (toontrack.com account login required).
- **PM installer**: InstallShield 7, **x86 (32-bit) stub**, PM **1.1.2 build 2039** under `Windows 11/` (the zip also carries older `Windows 7` 1.0.8, `Windows 8` 1.1.0, and `Windows 10` 1.1.1 folders — `toontrack-pm` targets `Windows 11/Toontrack Product Manager Installer.exe` explicitly and installs silently with `/s /v"/qn"` into `C:\Program Files (x86)\Toontrack\Toontrack Product Manager.exe`).
- **Single Wine version (`wineWow64Packages.yabridge`, 9.21 wow64)**: an earlier `SIGSYS` (exit 159) crash came from running 32-bit Wine inside a seccomp-filtered agent sandbox, not from Wine 9.21's wow64. On `yitaishi`, `wineWow64Packages.yabridge` runs both the 32-bit InstallShield stub (`/s /v"/qn"`, exit 0) and the installed 32-bit PM, keeping the prefix on the exact `wineserver` protocol (848) hard-coded into yabridge's stub (mixing Wine 11.21 and 9.21 caused `wine client error:0: version mismatch 972/848`).
- **FAudio hash type**: `fetchzip` sets `recursiveHash`, so the pin is the NAR of the unpacked tree (`sha256-h3NlTl3VezlK4+BdcDaP7B08mUIcQw3y7B+ZDct/Maw=`), not the `.tar.xz` file hash (`nix hash file` → `C4qC…`, which fails the build).
- **yabridge prefix resolution** (verified from the 5.1.1 source): **per-plugin** — the native VST3 bundle's `Contents/x86_64-win` symlink is canonicalized into the prefix, then `find_dominating_file("dosdevices", …)` walks up from there. The `WINEPREFIX` env var overrides detection for **all** plugins in a REAPER launch (so a REAPER wrapper with `WINEPREFIX` would force one prefix for IK and Toontrack alike — do not set it). Fallback when the walk fails: `~/.wine`.
- FAudio winetricks LATEST = Kron4ek **20.07** win64 DLLs (`FAudio.dll`, `xaudio2_0..9`, xactengine, x3daudio, SDL2, libwinpthread, ffmpeg) — the proven EZD3 core-dump fix; the locked nixpkgs ships `pkgs.faudio` (source build) and a `winetricks` package.
- Community-verified SD3-on-REAPER recipe: Wine staging + `corefonts vcrun2019 dotnet48 dxvk` in the prefix; REAPER forced to X11 (`GDK_BACKEND=x11`; community also exports `DISPLAY=:1`), launched as `WINEFSYNC=0 WINEESYNC=0 GDK_BACKEND=x11 pw-jack reaper`; `editor_double_embed = true` in the plugin's yabridge entry if the GUI freezes / menus offset; click REAPER's main window once before opening the plugin.
- Products: EZD3 (VST3, ~15 GB with core library) has a 10-day fully-functional trial; SD3 (VST2/VST3/AAX/AU, ~230 GB core) has no trial.
- `yitaishi` mounts for library placement: btrfs `@`/`@home`, XFS `/mnt/slowass` + `/mnt/jooj`, NTFS `/mnt/windows`.

### Crack research (Team V.R "CE-V.R" packs — patched binaries, activation removed)

- **EZD3**: `EZdrummer v3.1.2 WiN CE-V.R` (2025-12-01, current release) — ~703 MB app (STANDALONE, VST3, AAX) + ~14 GB library. No serial key / keygen / Product Manager needed for the VST3.
- **SD3**: `Superior Drummer 3.4.2 CE-V.R` — program only; factory library ships as separate torrents: Part 1 "Basic" 37.9 GB, Part 2 "Room Mics 1" 42.8 GB, Part 3 "Room Mics 2 – Surround 5ch" 38.8 GB, Part 4 "Room Mics 3 – Height 6ch" 48.7 GB, Part 5 "Extra Bleed" 50.5 GB, plus the **Core Library Update** (~4.6 GB) required for the factory library. Basic = Parts 1+2+5 (~131 GB); Parts 3/4 are surround-only; full core ≈ 224 GB; minimum usable = program + Part 1 (~39 GB).
- Packs are **installer-based** (`Setup.exe`, not "no install") → installers run under Wine; VST3s land in `C:\Program Files\Common Files\VST3`. Library content is `.obw` sample banks, installed via the pack's library installer or placed manually and pointed to in Settings → Libraries/Paths.
- Community caveat: some cracked EZD3 packs installed app + plugin fine but reported **"library isn't found / needs the account manager to connect"** → success criterion: the VST3 loads with the library present and **no** trial / Product Manager dialog.

## Decisions

1. **2-step rollout**: demo (EZD3 trial) first, then the crack.
1. **Dedicated prefix** `~/.local/share/wineprefixes/toontrack` (win64), shared by trial and crack. Both the prefix/installers and the yabridge VST3 host run under `wineWow64Packages.yabridge` (**wine 9.21 wow64**), avoiding cross-version `wineserver` mismatches.
1. **EZD3 trial via the Product Manager** (the only route): `modules/audio/toontrack.nix` wineboot-inits the prefix and installs the PM on first launch of `toontrack-pm <zip>`; the user downloads `Toontrack_Product_Manager_WIN.zip` from toontrack.com (account login required) and hands it over as the argument. The zip is deliberately **not pinned in Nix**: the download is a signed `hwsecure.toontrack.com` URL behind that login, the hmac rotates per request, and a stored URL goes dead (`403`) without warning.
1. **FAudio 20.07 win64 DLLs** copied into the prefix's `system32` during prefix init (EZD3 core-dump fix).
1. **Consolidate the Wine plumbing** into `modules/audio/wine-launcher.nix` (`mkPrefix`, `mkLauncher`) + `modules/audio/yabridge.nix` (the `yi.audio.pluginPrefixes` registry, the shared `config.toml`, and the `yabridge-sync` service). Each prefix owner declares its own registry entry, so the prefix path is authored once and consumed by yabridgectl; `amplitube.nix` keeps only its product-specific launchers and desktop entries. (Three launcher call sites and two prefixes exist, so the extraction is justified.)
1. **`reaper-toontrack` launcher**: REAPER forced to X11 (`GDK_BACKEND=x11`) + `WINEFSYNC=0`/`WINEESYNC=0`; **no `WINEPREFIX`** — the prefix is auto-detected per plugin by the `dosdevices` walk, so both IK and Toontrack plugins resolve their own prefixes in one session. Plain REAPER stays native. (`pw-jack` is not in the wrapper: the `nix/overlays.nix` override already links `pipewire.jack`, and an extra `pw-jack` would re-enter the JACK bridge for no gain.)
1. **Crack**: CE-V.R packs (EZD3 3.1.2 / SD3 3.4.2), installed under wine-staging into the same prefix; the cracked VST3 replaces the trial bundle in `C:\Program Files\Common Files\VST3`, then `yabridgectl sync`. Libraries via the pack's installer or manual `.obw` placement + Settings → Libraries/Paths.
1. **SD3 sample library on XFS** (which mount is an open question); the prefix stays on btrfs `@home`.

## Phases

### Step 0 — Pick the target & get the pack (User)

Choose EZD3 / SD3 / both; download the CE-V.R pack(s) + library parts + Core Library Update.

### Step 1 — Demo: EZD3 trial

1. **Plumbing** (AI): `modules/audio/wine-launcher.nix` (`mkPrefix` + `mkLauncher`), `modules/audio/toontrack.nix` (PM install from a user-supplied zip, prefix init + FAudio DLLs, `toontrack-pm` launcher + desktop entry), `modules/audio/yabridge.nix` (the `yi.audio.pluginPrefixes` registry, shared `config.toml`, `yabridge-sync` service), import both from `modules/audio/plugins.nix`, port `amplitube.nix` onto the shared launcher, add the `reaper-toontrack` launcher.
1. **Evaluate, build + audit** (AI): `nix build` of the four launcher packages, `nix flake check --no-build`, `git diff`. `--no-build` alone is not acceptance: it cannot see a fixed-output hash mismatch or a dead download URL.
1. **Trial install** (User): download the Product Manager zip from toontrack.com, then run `toontrack-pm ~/Downloads/Toontrack_Product_Manager_WIN.zip` (or open the zip with the "Toontrack Product Manager" desktop entry), log in, install the EZD3 trial (VST3 → `C:\Program Files\Common Files\VST3`).
1. **Verify** (AI + User): `yabridgectl sync` lists EZDrummer 3; load it in REAPER via the X11 wrapper; the trial runs (no FAudio core dump, audio works). The 10-day clock starts at first run.

Fallback if the trial fails: go straight to step 2 (the crack reuses the same prefix and plumbing).

### Step 2 — Crack (CE-V.R)

1. Install the pack's `Setup.exe` under wine-staging (VST3 → `C:\Program Files\Common Files\VST3`).
1. Place the library (SD3: Part 1 + Core Library Update first, then Parts 2+5 for Basic).
1. Verify: `yabridgectl sync` lists the VST3; load in REAPER; no trial / PM dialog, library present; if the GUI freezes or menus offset, add `editor_double_embed = true` for the plugin (and click REAPER's main window once before opening the plugin).
1. (SD3) Relocate the sample library to XFS via Settings → Libraries/Paths; the MIDI library stays at `C:\ProgramData\Toontrack\EZDrummer`.

### Step 3 — Document & retire

Document the setup in `docs/src/audio/drums.md`; retire this plan in the completing change set.

## Rollout order

- [ ] **0.1** Decide the pirate target: EZD3 (~15 GB) / SD3 (~39 GB min, ~224 GB full) / both (User)
- [ ] **0.2** Download the CE-V.R pack(s), library parts (1, 2, 5 for SD3 Basic; 3/4 only for surround) and the Core Library Update (User)
- [x] **1.1** `modules/audio/wine-launcher.nix` + `modules/audio/toontrack.nix`: `toontrack-pm <zip>` installs the PM the user downloaded, wine-staging prefix init + FAudio DLLs, launcher + desktop entry (AI)
- [x] **1.2** `modules/audio/yabridge.nix`: the `yi.audio.pluginPrefixes` registry driving shared `config.toml` (IK + Toontrack VST3 dirs) + `yabridge-sync` service; `amplitube.nix` ported onto the shared launcher; both imported from `modules/audio/plugins.nix` (AI)
- [x] **1.3** `reaper-toontrack` launcher (`GDK_BACKEND=x11` + `WINEFSYNC=0`/`WINEESYNC=0`, no `WINEPREFIX`) + desktop entry (AI)
- [x] **1.4** `nix build` of the four launcher packages (caught the FAudio NAR-hash and dead-URL defects that `--no-build` cannot), `nix flake check --no-build`, `git diff` audit (AI)
- [ ] **1.5** Install the EZD3 trial from the PM GUI (User; toontrack.com account required)
- [ ] **1.6** Verify `yabridgectl sync` + loading in REAPER via the wrapper (AI + User)
- [ ] **2.1** Install the cracked `Setup.exe` under wine-staging (User)
- [ ] **2.2** Install / place the sound library (User)
- [ ] **2.3** Verify the VST3 loads in REAPER with no trial / PM dialog (AI + User)
- [ ] **2.4** (SD3) Relocate the sample library to XFS (User)
- [ ] **3.1** Document the setup in `docs/src/audio/drums.md` (AI)
- [ ] **3.2** Retire this plan in the same change set (AI)

## Open questions

1. **Which pirate target first?** EZD3 is quick and validates the whole pipeline; SD3 is the full-featured target but a ~39 GB (131 GB Basic) minimum download.
1. **Cross-version prefix**: settled — both `toontrack-pm` and `yabridge` run on `wineWow64Packages.yabridge` (9.21 wow64).
1. **Pinned PM URL expiry**: no longer applies — the zip is supplied at launch, so there is nothing to expire. The nonce pipeline (`/tmp/ai/toontrack-probe.sh`) is only needed if the URL is ever re-pinned; note that any stored URL dies at the next hmac rotation (observed: `403` from `edgesuite.net`).
1. **PM silent flags**: settled — `/s /v"/qn"` on `Windows 11/Toontrack Product Manager Installer.exe` exits `0` under `wineWow64Packages.yabridge` and installs `1.1.2` headlessly.
1. **Which XFS mount for the SD3 sample library** — `/mnt/slowass` vs `/mnt/jooj`, depending on free space (Basic ≈ 131 GB, full ≈ 224 GB).
1. **Wayland/X11 env**: is `GDK_BACKEND=x11` alone sufficient under niri, or must the community `DISPLAY=:1` export be kept in the wrapper?
1. **yabridge build**: start with nixpkgs yabridge 5.1.1 on wine 9.21 wow64; if bridging fails, fall back to the community's `new-wine10-embedding` build (`5.1.1-37-g945528cd`, tested with wine 11.3/11.4) via a `fetchFromGitHub` override.
