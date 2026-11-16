# New Gang Compute Host Research

Status: options updated with burst-contention data and 2026-11-16 prices; purchase and hostname undecided; R$ 12.000 ceiling\
Reviewed: 2026-11-16

This document compares ways to spend up to R$ 12.000 on the gang's compute,
memory, and local AI capacity. `yifuwuqi` has run short of memory for 3–12 hours
a day since Nov 10, its CPU runqueue and QLC SSD also saturate during
compilations and cache writes, and local AI is split between a slow integrated
GPU on `yifuwuqi` and a fast RX 7900 XTX on `yitaishi`, which is off at night.

## Summary

- **A new box is required to protect Minecraft.** Adding RAM to `yifuwuqi`
  stops OOM kills, but 1-minute Prometheus data shows separate CPU and SSD
  saturation while free RAM exceeded 2 GiB: 491 minutes of >10% CPU runqueue
  stall (peak 97.4%), 14.8-thread `rustc` and 12.9-thread Node.js bursts, and
  119 minutes of >80% NVMe busy with average write latency reaching 445 ms on
  its 86%-full DRAM-less QLC SSD. Any of those stalls breaks a 50 ms (20 TPS)
  tick budget.
- **Put Minecraft and 24/7 Gemma on the new Zen 4 box, not just `workd`.** If
  only `workd` moves and Minecraft stays on `yifuwuqi`, Minecraft still shares a
  Zen 3+ CPU, 19.3 GiB of RAM, and the 86%-full QLC drive with CI
  (`nix-eval-jobs`, evening fallback builds when `yitaishi` is off), `atticd`
  (9.7 threads, 95% NVMe busy), and media writes. Moving Minecraft and Gemma to
  a dedicated 32 GB Zen 4 mini PC (`remoteBuilder = false`) isolates them from
  every build and heavy-write workload.
- **For AI capability, +32 GB on `yitaishi` (~R$ 4.240–4.277) beats every mini
  PC under the ceiling.** No AI-specific mini PC (Ryzen AI 9 HX 370 at R$ 13.899,
  Ryzen AI Max+ 395 at R$ 22.049) fits R$ 12.000, and a 780M mini PC only makes
  Gemma ~17% faster. Upgrading `yitaishi` to 64 GB lets its RX 7900 XTX run
  ~60 GB mixture-of-experts models while keeping Gemma on the new mini PC as the
  overnight fallback.
- **Best combinations under R$ 12.000:**
  - **Option B2 (R$ 11.650–11.771):** 32 GB Zen 4 mini PC (**Beelink SER8** or
    **GMKtec K8**) for Minecraft + Gemma, plus **+32 GB on `yitaishi`** for AI
    and daytime `workd` compilations.
  - **Option E (R$ 10.909–10.993):** the same 32 GB Zen 4 mini PC for Minecraft
    and Gemma, plus **one 32 GB SO-DIMM in `yifuwuqi` (44 GB total)** if `workd`
    must stay 24/7 on headless `yifuwuqi` and >24 GiB models on `yitaishi` can
    wait.
  - **Option A′ (R$ 7.410–7.494):** buy the 32 GB Zen 4 mini PC first, move
    `workd` to `yitaishi` when at the desk, and buy RAM only if a model or
    headless `workd` demands it.
- Do the [free fixes](#free-fixes-before-buying) regardless of which option is
  chosen.

## Evidence and confidence

The labels used below prevent unlike evidence from being treated as
equivalent:

- **Repository fact**: declared by the checked-in Nix or Minecraft
  configuration.
- **Observed**: a read-only measurement. Point-in-time reads are from
  2026-11-16; history comes from `yifuwuqi`'s Prometheus, which holds node data
  from 2026-10-16 and per-process data from 2026-11-04.
- **Vendor specification**: capacity, speed rating, or claimed behavior; not
  independently verified.
- **Independent measurement**: a published test with its stated hardware and
  software; results do not transfer exactly to another machine.
- **Derived estimate**: arithmetic from specifications or measurements; not a
  measured result.
- **Market observation**: a listing price seen on 2026-11-16; volatile, and not
  a quote.

No candidate hardware has been tested here.

## Measured state

### `yifuwuqi`

- **Observed:** a Beelink EQR6 (DMI `AZW EQ`) with a Ryzen 9 6900HX (8 Zen 3+
  cores, 16 threads) and Radeon 680M. Both SO-DIMM slots hold 12 GB Crucial DDR5
  modules, rated 5600 but running at 4800 MT/s; firmware reports a 64 GiB
  maximum and Linux sees 19.3 GiB. Storage is one 1 TB Crucial P3 Plus NVMe
  (`CT1000P3PSSD8`); the second M.2 slot is empty.
- **Vendor specification / independent measurement:** the EQR6 takes up to
  64 GB (2×32 GB) and two M.2 2280 SSDs. The Crucial P3 Plus is a DRAM-less QLC
  drive; published full-drive tests (ComputerBase, PC Gamer) show sequential
  writes dropping from ~3.6 GB/s to **70–90 MB/s** once its dynamic pSLC cache
  fills, and pSLC capacity shrinks as free space drops.

Thirty-day averages (`3.8%` CPU busy, `14.5%` 5-minute p95) look idle because
compilations and game sessions are bursty. One-minute windows over the last
30–31 days show severe contention in memory, CPU runqueue, and NVMe writes
(**Observed**):

| Signal                                                               | Observed value                                                                       |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Hours per day with less than 1 GiB available                         | 0–4 through Nov 9; 3–12 since Nov 10; 11 in the last 24 hours                        |
| Minimum available memory / zram swap peak                            | 0 (Nov 3 and Nov 4) / 20.4 of 20.7 GB                                                |
| Memory full stall (`PSI`, 5-minute windows)                          | 2.3% p99, 31% maximum                                                                |
| Kernel OOM kills                                                     | 1 on Nov 3; one more counter increment on Nov 15–16 has no matching journal entry    |
| CPU busy >80% (`1m`), while `MemAvailable > 2 GiB`                   | 257 minutes (287 minutes total); 100% peak; CPU temp peak 85.6 °C                    |
| CPU runqueue stall (`PSI` "some" >10%, `1m`), `MemAvailable > 2 GiB` | 491 minutes (~8.2 hours; 570 total, 343 >25%); **97.4% peak**                        |
| NVMe busy >80% (`1m`), while `MemAvailable > 2 GiB`                  | 119 minutes (100% of all >80% minutes); **100% peak** at 41–85 MiB/s write rates     |
| NVMe 1-minute average write latency peak, `MemAvailable > 2 GiB`     | **445 ms** (`PSI` I/O full stall: 335 minutes >5%, 55 minutes >20%, 50.6% peak)      |
| Total data written to `nvme0n1` in 30 days                           | 4.84 TiB (~26% of the drive's 220 TBW rating per year)                               |
| Overlap while Minecraft was resident (2,211 min in last 12 days)     | 61 min `load1 > 8`; 35 min mem stall >5%; 24 min CPU stall >10%; 8 min I/O stall >5% |

Peak memory and peak 1-minute CPU thread use by process group from Nov 4 to
Nov 16, on a 16-thread CPU (**Observed**):

| Process group                                                                                    | Memory peak (RSS + swap) | 1m CPU peak      | When                            |
| ------------------------------------------------------------------------------------------------ | ------------------------ | ---------------- | ------------------------------- |
| Node.js (`MainThread`): `workd` dev servers, editor/agent tooling, SillyTavern                   | 18.4 GiB                 | 12.9 threads     | Weekdays, 09:00–16:00 local     |
| `rustc` (Rust compilations)                                                                      | 4.7 GiB (resident)       | 14.8 threads     | Dev and build bursts            |
| `nix-eval-jobs` (CI evaluation)                                                                  | 13.6 GiB                 | —                | CI runs                         |
| `zstd` (Minecraft world backup)                                                                  | 11.9 GiB                 | 7.7 threads      | During world backups            |
| Minecraft JVM (`java` / `.java-wrapped`)                                                         | 9.5 GiB                  | 12.5 threads     | ~3 hours/day resident           |
| `nix` / `cc1plus` / `next-build` / `bun` / `python3.14`                                          | up to 8.7 GiB            | 3.4–12.1 threads | Compilations and builds         |
| `atticd` / `attic` (binary cache server and store push)                                          | 6.9 GiB (resident)       | 9.7 threads      | Post-build cache uploads        |
| Gemma 4 12B (`llama-server`)                                                                     | 6.7 GiB                  | —                | 887 minutes resident in 12 days |
| System services and containers: Arr, Jellyfin, PostgreSQL, monitoring, Forgejo, Attic, Firecrawl | 4.6 GiB together         | low steady       | 24/7 (Arr/media is ~1.5 GiB)    |

Disk and network (**Observed**):

- The ext4 root is 915 GiB with 744 GiB used (86%) and 125 GiB free;
  `/persist/media` is 466 GiB. Free space was 129 GiB 30 days ago and 73 GiB
  7 days ago: media capacity is not growing fast, but keeping the QLC drive 86%
  full shrinks its write cache.
- `eno1` and `enp4s0` negotiate 100 Mb/s. Both ran at 1 Gb/s within the last
  30 days, and `eno1` received up to 85 MB/s (5-minute average) in that time.
  This regression throttles Jellyfin, Attic substitution, and remote builds.

### `yitaishi`

- **Observed:** an ASUS PRIME X670-P (BIOS 3602) with a Ryzen 7 7700X and RX
  7900 XTX (24 GiB). Two of four DIMM slots hold a 2×16 GB Corsair Vengeance
  DDR5-5600 CL36 kit (`CMK32GX5M2B5600C36`) running at 5600 MT/s; Linux sees
  30.5 GiB. `sd-cpp.service` uses 57 MiB at idle (`--offload-to-cpu` stages
  weights in host RAM only during generation).
- **Vendor specification:** AMD rates the 7700X at DDR5-5200 with two DIMMs and
  DDR5-3600 with four, up to 128 GB.
- **Observed:** from Nov 13 to Nov 16 the workstation was off for 9–10 hours
  every night and on during daytime and evening hours (~12–18 hours/day).
- **Observed:** Qwen 3.8 27B (UD-Q4_K_XL, Vulkan) served 50 requests from Nov 7
  to Nov 16 at a median **39.8 tokens/s** generation speed and **670 tokens/s**
  prompt processing on prompts of 2K tokens or more.
- **Repository fact:** `yitaishi` already enables `host.workd = true`, has
  `speedFactor = 360` as the preferred remote Nix builder when online, and is
  excluded from `monitoring.scrapeHosts` and `logHosts`.

### Constraints shared by every option

- **Repository fact:** `llama-cpp` uses Vulkan, one loaded model at a time, Q8
  KV cache, one slot, and a five-minute idle unload. Gemma 4 12B Q4 (32K
  context) targets `yifuwuqi`; Qwen 3.8 27B Q4 (64K) and `chroma1-hd` target
  `yitaishi`.
- **Repository fact:** `mc-aset-loveland` (`bias`) sets an 8 GiB heap and 10 GB
  container limit, five players max, simulation distance 8, view distance 12,
  pause-when-empty after 120 seconds, C2ME, and Distant Horizons with
  `numberOfThreads = 12` and 512-chunk LOD generation radius. Compose remains
  manual, images are loaded by hand, its Phase 2 runtime test is still pending,
  and the main flake does not consume the sibling flake.
- **Repository fact:** when `yitaishi` is powered off at night,
  `nix.settings.fallback = true` and `yifuwuqi`'s `remoteBuilder = true`
  (`maxJobs = 16`, `cores` unlimited) run builds on `yifuwuqi` alongside local
  `forgejo-runner` and `github-runner` jobs.
- **Repository fact:** `workd` runs on `yifuwuqi` so ports 3000/6006 (opened on
  `eno1`) and remote editor sessions stay reachable 24/7 on the LAN.

## Why Minecraft needs its own host — and which side moves

Minecraft's main tick is single-thread latency-bound (50 ms per tick for
20 TPS), while Distant Horizons (`12` threads) and C2ME burst across cores and
flush region/LOD data to disk. On `yifuwuqi`, three non-memory bottlenecks hit
it even if RAM is upgraded to 64 GB:

1. **CPU runqueue and TDP contention:** `rustc` (14.8 threads), Node.js
   `MainThread` (12.9 threads), `python3.14` (12.1 threads), and `atticd`
   (9.7 threads) contend directly with Minecraft's 12.5-thread peaks on an
   8-core/16-thread 45 W mini PC, producing up to 97.4% 1-minute CPU wait.
1. **QLC SSD write stalls:** at 86% fill, 41–85 MiB/s of `rustc`, `nix-daemon`,
   or `atticd` writes push `nvme0n1` to 95–100% busy and 445 ms average write
   latency, stalling world saves and chunk loads.
1. **Nighttime builder fallback:** `yitaishi` is off overnight, so evening CI or
   laptop builds land on `yifuwuqi` during Minecraft play hours.

Once a second 32 GB Zen 4 mini PC is added, **moving Minecraft + 24/7 Gemma to
the new box beats moving only `workd` and leaving Minecraft on `yifuwuqi`**:

| Split                                                             | Minecraft CPU & SSD                                                                      | Minecraft isolation                                                        | Remaining pressure on `yifuwuqi` (24 GB)                                                              |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Recommended:** Minecraft + Gemma on new Zen 4 box               | Faster Zen 4 IPC; disk \<10% used (avoids QLC full-drive cliff); ~18 GiB peak in ~29 GiB | Complete: `remoteBuilder = false`, no `workd`, no CI, no `atticd`/torrents | Daytime `workd` (18.4 GiB) + CI (13.6 GiB) still exceed 19.3 GiB unless `workd` moves or RAM is added |
| Alternative: `workd` + builds on new box; Minecraft on `yifuwuqi` | Older Zen 3+; stays on 86%-full QLC SSD (445 ms stalls); 4.6 + 9.5 + 6.7 GiB > 19.3 GiB  | Partial: still shares `yifuwuqi` with `atticd`, CI runners, and torrents   | Daytime `workd` leaves, but evening `atticd`/CI/torrent bursts still hit Minecraft                    |

## Free fixes before buying

1. Fix link negotiation on `yifuwuqi` (`eno1` and `enp4s0` are stuck at
   100 Mb/s).
1. Replace `-T0` with `-T2` for `zstd` in `mc-aset-loveland/scripts/backup.sh`
   to cut the 11.9 GiB / 7.7-thread backup spike on whichever host runs
   Minecraft.
1. Cap `nix-eval-jobs` in `ci/build.sh` (for example `--workers 1` and a lower
   `--max-memory-size` than the 4 GiB/worker default) and set explicit
   `nix.settings.cores` / lower `CPUWeight` and `IOWeight` on
   `nix-daemon.service`, `forgejo-runner-yifuwuqi.service`, and
   `atticd.service`.

## Options

Costs use verified cash/PIX listings from 2026-11-16 (see
[Market data](#market-data-2026-11-16)).

| Option | Purchase                                                                     | Cost (R$)         |
| ------ | ---------------------------------------------------------------------------- | ----------------- |
| **B2** | **SER8 (8745HS) or K8 (8845HS) 32 GB/1 TB + `yitaishi` +2×16 GB DDR5**       | **11.650–11.771** |
| **E**  | **SER8 or K8 32 GB/1 TB + `yifuwuqi` +1×32 GB DDR5-4800 SO-DIMM (to 44 GB)** | **10.909–10.993** |
| **A′** | **Beelink SER8 (8745HS) or GMKtec K8 (8845HS): Radeon 780M, 32 GB, 1 TB**    | **7.410–7.494**   |
| A      | Beelink SER9 MAX: H 255, Radeon 780M, 64 GB, 1 TB                            | 12.900            |
| B1     | N150 mini PC (16 GB) + `yitaishi` +2×16 GB + 8 TB HDD                        | 9.296 + enclosure |
| C      | `yifuwuqi` 2×32 GB SO-DIMM (replacing 2×12 GB)                               | 6.998             |
| D      | C + `yitaishi` +2×16 GB                                                      | 11.238–11.275     |

| Option | Minecraft isolated from builds/QLC  | `yifuwuqi` memory                                   | 24/7 AI           | ~60 GB MoE on `yitaishi`      | Storage added | Migration work |
| ------ | ----------------------------------- | --------------------------------------------------- | ----------------- | ----------------------------- | ------------- | -------------- |
| **B2** | **Yes (dedicated Zen 4 host)**      | **Yes if `workd` runs on `yitaishi`; tight if not** | Gemma ~17% faster | **Yes (while `yitaishi` on)** | 1 TB NVMe     | Medium         |
| **E**  | **Yes (dedicated Zen 4 host)**      | **Yes (~40 GiB usable; keeps 24/7 `workd`)**        | Gemma ~17% faster | Deferred                      | 1 TB NVMe     | Medium         |
| **A′** | **Yes (dedicated Zen 4 host)**      | Only if `workd` moves to `yitaishi`                 | Gemma ~17% faster | No                            | 1 TB NVMe     | Medium         |
| A      | Yes (can also host `workd` if solo) | Partly; mostly if `workd` moves too                 | Gemma ~17% faster | No                            | 1 TB NVMe     | Medium         |
| B1     | No (N150 too weak; stays on QLC)    | No (moves ~1.5 GiB)                                 | Unchanged         | Yes (while `yitaishi` on)     | 8 TB HDD      | High           |
| C      | No (CPU and QLC stalls remain)      | Yes                                                 | Unchanged         | No                            | None          | None           |
| D      | No (CPU and QLC stalls remain)      | Yes                                                 | Unchanged         | Yes (while `yitaishi` on)     | None          | Low            |

### B2: 32 GB Zen 4 mini PC + `yitaishi` +32 GB (AI + isolation target)

- Isolates Minecraft and 24/7 Gemma on the new 32 GB Zen 4 host (`remoteBuilder = false`),
  and upgrades `yitaishi` from 32 GB to 64 GB so its RX 7900 XTX can run ~60 GB
  MoE models and large `workd` sessions.
- Run heavy `workd` dev servers/compilations on `yitaishi` while at the desk (or
  cap `nix-eval-jobs` on `yifuwuqi`) so `yifuwuqi`'s 24 GB only carries core
  services, Arr, and CI.

### E: 32 GB Zen 4 mini PC + `yifuwuqi` +32 GB SO-DIMM (24/7 headless `workd` target)

- Same dedicated Zen 4 host for Minecraft + Gemma, while replacing one 12 GB
  SO-DIMM in `yifuwuqi` with 32 GB (44 GB total, ~40 GiB usable) so 24/7
  headless `workd` (ports 3000/6006, remote editor) and CI coexist on `yifuwuqi`
  without OOMs.
- Asymmetric 32 + 12 GB runs 24 GB in dual channel and 20 GB in single channel;
  once Gemma leaves `yifuwuqi`, nothing left on `yifuwuqi` depends on iGPU
  memory bandwidth. `+32 GB` on `yitaishi` (~R$ 4.240–4.277) can be bought later
  when a >24 GiB model is chosen.

### A′: 32 GB Zen 4 mini PC first (SER8 vs GMKtec K8)

Both verified R$ ~7.4k options use 8 Zen 4 cores, Radeon 780M, 2×16 GB
DDR5-5600 SO-DIMMs (expandable to 64 GB), and dual M.2 2280 PCIe 4.0 x4 slots:

| Model            | Price (R$) | CPU (boost)      | Wired NIC           | Reviewed 1 TB SSD                | Cooling and acoustics (independent reviews)                                             |
| ---------------- | ---------- | ---------------- | ------------------- | -------------------------------- | --------------------------------------------------------------------------------------- |
| **Beelink SER8** | 7.410      | 8745HS (4.9 GHz) | 1× 2.5GbE (RTL8125) | Crucial P3 Plus (QLC, DRAM-less) | Vapor chamber; ~28.8 dBA idle / 34.6 dBA load, ~7.3 W idle (Notebookcheck)              |
| **GMKtec K8**    | 7.494,21   | 8845HS (5.1 GHz) | 2× 2.5GbE (RTL8125) | Lexar NM7A1 (TLC)                | Dual fan; ~38.3 dBA idle / 47.7 dBA load, hits 90 °C unless BIOS Quiet set (Liliputing) |

- Pick **SER8** for quiet 24/7 operation; on a dedicated Minecraft + Gemma box
  using \<50 GB of 1 TB, the Crucial P3 Plus keeps a large pSLC cache and avoids
  the 86%-full cliff seen on `yifuwuqi`.
- Pick **GMKtec K8** if dual 2.5GbE or a TLC SSD out of the box matters more
  than fan noise.
- A cheaper **Beelink SER6 Max** (Ryzen 7 7735HS Zen 3+, Radeon 680M, 32 GB/1 TB,
  R$ 6.132,66 on Carrefour marketplace with a 90-day seller warranty) saves
  ~R$ 1.280, but gives up Zen 4 single-thread IPC, 780M bandwidth, and warranty
  length.

### A, B1, C, and D: why they rank lower

- **A (SER9 MAX 64 GB, R$ 12.900):** exceeds the R$ 12.000 ceiling at its only
  verifiable Brazilian listing (lower R$ 8.490–9.740 aggregator results could
  not be verified). Putting both `workd` and Minecraft onto one 64 GB SER9 MAX
  would recreate the CPU contention this purchase is meant to remove.
- **B1 (N150 + `yitaishi` RAM + 8 TB HDD, R$ 9.296 + enclosure):** four N150
  cores cannot run this modded Minecraft server, moving Arr/Jellyfin frees only
  ~1.5 GiB on `yifuwuqi`, and moving web UIs forces an ingress refactor while
  media disk usage is currently flat.
- **C and D (`yifuwuqi` RAM without a new host, R$ 6.998 / R$ 11.238–11.275):**
  solve `yifuwuqi` memory exhaustion, but leave Minecraft exposed to `rustc`,
  `workd`, `atticd`, nighttime fallback builds, and QLC write stalls.

## Money per unit

| Resource | Product                                                       | Price (R$)                                     | Unit cost               |
| -------- | ------------------------------------------------------------- | ---------------------------------------------- | ----------------------- |
| Host     | Complete Zen 4 + 780M + 32 GB + 1 TB mini PC (SER8 / K8)      | 7.410–7.494                                    | Baseline new node       |
| RAM      | SER9 MAX's extra 32 GB over SER8                              | 5.490 verified (2.330 at unverified R$ 9.740)  | R$ 172/GB (or R$ 73/GB) |
| RAM      | `yitaishi` +32 GB: generic DDR5-6000 or matched Corsair 5600  | 4.240–4.277 (or 8.000 for 2×32 GB replacement) | R$ 132–134/GB (or 125)  |
| RAM      | Laptop DDR5: one 32 GB DDR5-4800 or 2×32 GB DDR5-5600 kit     | 3.499 or 8.500                                 | R$ 109/GB or R$ 133/GB  |
| RAM      | Option E net gain on `yifuwuqi` (+20 GB, replacing one 12 GB) | 3.499                                          | R$ 175/GB net           |
| Storage  | 8 TB NAS HDD vs 4 TB PCIe 4.0 NVMe                            | 2.957 vs 6.900                                 | R$ 370/TB vs 1.725/TB   |

## Local AI performance

For **loading** a model, memory capacity is the hard limit. For **running** it,
capacity beyond the fit adds no speed:

```text
model fits       ≈ weights + KV cache + runtime + other services < usable memory
decode ceiling   ≈ memory bandwidth / bytes read per generated token
```

Dense models read every weight per token; mixture-of-experts (MoE) models read
only the active subset, so large MoE models remain usable on DDR5 bandwidth once
they fit.

| Platform                             | Memory bandwidth | Gemma 4 12B Q4            | Qwen 3.8 27B Q4          | Larger models                               |
| ------------------------------------ | ---------------- | ------------------------- | ------------------------ | ------------------------------------------- |
| `yifuwuqi` 680M, DDR5-4800           | 76.8 GB/s        | ~9 tokens/s (derived)     | Does not fit today       | None                                        |
| SER8 / K8 / SER9 MAX 780M, DDR5-5600 | 89.6 GB/s        | ~10–11 tokens/s (derived) | ~4–5 tokens/s (derived)  | 26B-A4B MoE at 23–25 tokens/s (independent) |
| `yitaishi` RX 7900 XTX (24 GiB VRAM) | 960 GB/s         | ~70–95 tokens/s (derived) | 39.8 tokens/s (observed) | ~60 GB MoE with 64 GB of system RAM         |

- Integrated-GPU estimates scale a published Radeon 780M result (7B Q4 at
  19–20 tokens/s on llama.cpp Vulkan) by bandwidth and parameter count. The new
  780M box is the **24/7 fallback** for Gemma 12B while `yitaishi` sleeps, not
  the primary heavy-AI engine.
- Prompt processing dominates agent/tool workflows: `yitaishi`'s RX 7900 XTX
  measured **670 tokens/s** on 2K+ token prompts with Qwen 27B, with roughly
  seven times the compute of a 780M (and more over the 680M).
- **Derived estimate:** a ~60 GB MoE model (`gpt-oss-120B`, ~59 GiB weights,
  ~5.1B active parameters) on `yitaishi` with 64 GB RAM keeps attention/KV on
  the GPU and streams active experts from system RAM at roughly **15–25
  tokens/s**, with fast GPU prompt processing.
- **`yitaishi` caveats:** it is off 9–10 hours nightly; a ~60 GB model cannot
  coexist with heavy gaming, VR, `sd-cpp` sampling, or an 18 GiB `workd` stack;
  and adding a second 2×16 GB kit (`CMK32GX5M2B5600C36`) populates four DIMMs,
  which AMD only guarantees at DDR5-3600 (~36% less expert bandwidth unless the
  PRIME X670-P trains four single-rank sticks at 4800–5200 MT/s). A 2×32 GB
  replacement avoids four DIMMs for R$ 8.000, which pushes a combined purchase
  past R$ 12.000.
- NPUs are unused: the stack builds `llama.cpp` with Vulkan (`gfx1103` RADV on
  780M, `gfx1100` RADV on 7900 XTX).

## Minecraft fit on the new host

- **Proposed target, not measured:** 20 TPS with p95 MSPT below 40 ms at up to
  five players, simulation distance 8, view distance 12, C2ME, and Distant
  Horizons (`numberOfThreads = 12`) while Gemma inference is active.
- Keep the existing 8 GiB heap / 10 GB container limit initially, set higher
  `CPUWeight` on Minecraft than on `llama-cpp` and backups, cap `zstd` backup
  threads, and keep `remoteBuilder = false`. GPU inference and the JVM still
  share the 89.6 GB/s memory bus and 54–65 W package budget, so combined-load
  testing remains mandatory.
- The Playit tunnel is outbound, so moving Minecraft needs no public port or
  reverse-proxy vhost.

## Market data (2026-11-16)

| Item                                                                                                                                                                                                      | Price (R$)   | Where                  | Note                                                   |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ---------------------- | ------------------------------------------------------ |
| [Beelink SER8, 8745HS, 32 GB, 1 TB](https://www.amazon.com.br/Computadores-Desktop-Beelink-e-Inform%C3%A1tica/s?rh=n%3A16364751011%2Cp_89%3ABeelink)                                                      | 7.410        | Amazon (PIX)           | Quiet vapor-chamber Zen 4 + 780M; 1× 2.5GbE            |
| [GMKtec K8, 8845HS, 32 GB, 1 TB](https://www.mygigatech.com.br/mini-pc-gmktec-nucbox-k8-amd-ryzen-7-8845hs-1tb-ssd-32gb-ram-prata)                                                                        | 7.494,21     | MyGiga (PIX)           | Zen 4 + 780M; 2× 2.5GbE; louder fan curve              |
| [Beelink SER6 Max, 7735HS, 32 GB, 1 TB](https://www.carrefour.com.br/produto/mini-pc-beelink-ser-max-tb-gb-ram-amd-ryzen-hs-327487609)                                                                    | 6.132,66     | Carrefour (PIX)        | Zen 3+ / 680M; marketplace seller, 90-day warranty     |
| [GMKtec K8 Plus, 8845HS, 32 GB, 2 TB](https://www.amazon.com.br/GMKtec-K8-PCIe4-0-Windows-ventoinha/dp/B0CT33HCTG)                                                                                        | 9.119,05     | Amazon                 |                                                        |
| [Beelink SER9 MAX, H 255, 64 GB, 1 TB](https://www.amazon.com.br/Beelink-computador-desktop-tripla-10Gbps/dp/B0DWSLBS9B)                                                                                  | 12.900       | Amazon                 | Only verifiable listing; above the ceiling             |
| [Minisforum UM890 Pro barebone](https://www.amazon.com.br/dp/B0D9YLQMHX)                                                                                                                                  | 5.153,79     | Amazon                 | With 64 GB at retail, at least R$ 12.150 before an SSD |
| [Blackview MP60, N150, 16 GB, 512 GB](https://www.microgem.com.br/produto/mini-pc-blackview-mp60-twin-lake-n150-2-9ghz-mem-16gb-ssd-512gb-2x-hdmi-wifi-dual-band-bt-5-2-1xlan-rj45-gigabit-win-11-108409) | 2.098,80     | Microgem (PIX)         | DDR4, SATA SSD; too weak for modded Minecraft          |
| [Beelink EQ14, N150, 16 GB, 500 GB](https://www.mercadolivre.com.br/beelink-mini-pc-eq14-n150-16g-500g-ssd-wifi-windows/p/MLB61199250)                                                                    | 2.990,21     | Mercado Livre          |                                                        |
| Beelink SER9 Pro, HX 370, 64 GB, 2 TB                                                                                                                                                                     | 13.899       | Mercado Livre          | Above the ceiling                                      |
| [Minisforum AI X1 Pro, 96 GB](https://www.amazon.com.br/MINISFORUM-Pro-370-gr%C3%A1ficos-suporte-Copilot/dp/B0F47QT4XF)                                                                                   | 21.035,37    | Amazon                 | Above the ceiling                                      |
| [GMKtec EVO-X2, AI Max+ 395, 64 GB](https://alfatecnologico.com.br/products/amd-ryzen%E2%84%A2-ai-max-395-mini-pc-evo-x2-ai-128-gb-de-ram-2-tb-de-ssd)                                                    | 22.049       | Alfa Tecnológico       | Above the ceiling                                      |
| [Corsair Vengeance DDR5-5600 CL36, 2×16 GB (`CMK32GX5M2B5600C36`)](https://meupc.net/peca/bWr83X/memoria-corsair-vengeance-cmk32gx5m2b5600c36)                                                            | 4.277,21     | MeuPC.net              | Exact match for `yitaishi`'s installed kit             |
| [Desktop DDR5-6000, 2×16 GB](https://radarram.com.br/ram/)                                                                                                                                                | 4.239,99     | KaBuM, via RadarRAM    |                                                        |
| [Desktop DDR5-5600, 2×32 GB](https://radarram.com.br/ram/)                                                                                                                                                | 7.999,99     | KaBuM, via RadarRAM    | One offer; keeps 2-DIMM topology on `yitaishi`         |
| [Desktop DDR5-5600, 2×48 GB](https://radarram.com.br/comparar/ddr5-5600-2x48-vs-ddr5-6000-2x48/)                                                                                                          | Out of stock | RadarRAM               | 90-day low R$ 14.385,72                                |
| [Laptop DDR5-4800 SO-DIMM, 1×32 GB](https://radarram.com.br/ram/)                                                                                                                                         | 3.499,00     | KaBuM, via RadarRAM    | Fits `yifuwuqi` (Option E: 1×, Option C: 2×)           |
| [Laptop DDR5-5600 SO-DIMM, 2×32 GB](https://radarram.com.br/ram/)                                                                                                                                         | 8.499,99     | KaBuM, via RadarRAM    |                                                        |
| [WD Red Plus 8 TB](https://www.kabum.com.br/produto/567484/hd-8tb-nas-sata-5640rpm-256mb-cache-wd-red-plus-wd80efpx)                                                                                      | 2.956,80     | KaBuM (PIX)            |                                                        |
| [Kingston KC3000 4 TB](https://farejapreco.com.br/p/awin-17729-35913509699/ssd-kingston-kc3000-4tb-m-2-2280-pcie-4-0-x4-nvme-leitura-7000-mb-s-gravacao-700)                                              | 6.899,99     | KaBuM, via FarejaPreço |                                                        |

Marketplace and price-aggregator cards can mix SKUs or omit import taxes (for
example, unverified aggregator snippets at R$ 1.889 for a SER5 32 GB and
R$ 9.740 for a SER9 MAX 64 GB). Confirm the exact CPU, dual-channel RAM, SSD,
NIC, Brazilian invoice, return address, warranty, and local-voltage adapter
before paying.

### Import boundary

For direct imports within the US$3,000 simplified-remittance limit, Receita
Federal applies 60% import tax over product, freight, and insurance (minus
US$30 for Remessa Conforme sellers), then 17–20% ICMS calculated "inside"
(Receita page updated 2026-09-14). Ignoring the deduction, courier fees, and
exchange movement, the derived landed multiplier is about **1.93–2.00×** the
customs value: `1.60 / (1 - ICMS rate)`. At Beelink's US$1,159 store price for
the SER9 MAX 64 GB (2026-11-10), a direct import exceeds R$ 12.000 above
~R$ 5,18–5,37 per dollar.

## Codebase impact

| Area                                                                    | Current coupling                                                                                             | Options                                       | Required direction                                                     |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------------------------------- | ---------------------------------------------------------------------- |
| `flake.nix`, `nix/deploy.nix`                                           | Configurations and deploy nodes are enumerated separately; deploy activation is hardcoded to `x86_64-linux`  | B2, E, A′, A, B1                              | Add one x86 host explicitly                                            |
| `modules/addresses.nix`                                                 | Host registry is canonical; `monitoring.scrapeHosts` and `logHosts` are manual lists that exclude `yitaishi` | New host: B2, E, A′, A, B1; `yitaishi`: B2, D | Register the new host; opt both it and `yitaishi` into monitoring      |
| `modules/services/ai/models.nix`                                        | Model ownership uses `targetHost`; Gemma router on `yifuwuqi` is loopback-only                               | B2, E, A′, A                                  | Retarget Gemma to the new host and bind its LAN/Tailscale listener     |
| `modules/services/ai/llama-cpp.nix`                                     | Presets put every layer on one GPU (`-ngl 99`); there is no per-model CPU expert offload                     | B2, B1, D                                     | Add per-model offload flags in `models.nix` when adopting a ~60 GB MoE |
| `users/programs/opencode.nix`                                           | Providers are hardcoded for `yifuwuqi` and `yitaishi`                                                        | B2, E, A′, A                                  | Derive providers from `models.nix` + `addresses.nix`                   |
| `modules/services/ai/sillytavern.nix`                                   | Ports are read from `yifuwuqi`, and the unit `wants = [ "llama-cpp.service" ]` locally                       | B2, E, A′, A                                  | Drop the local unit dependency so UI stays on `yifuwuqi`               |
| `modules/services/proxy-vhosts.nix`, `modules/services/nginx-proxy.nix` | Generated proxy hops target `yifuwuqi`; `image.aset.love` to `yitaishi` is hand-written in `nginx-proxy.nix` | B1 (none for B2/E/A′)                         | Avoid moving web UIs now; add owner metadata later if web apps migrate |
| `mc-aset-loveland`                                                      | Sibling flake; Compose is manual; Phase 2 runtime test is pending                                            | B2, E, A′, A                                  | Complete the Phase 2 runtime test, then wire one flake boundary        |
| Distributed builds (`modules/addresses.nix`)                            | Hosts with `remoteBuilder = true` receive CPU-heavy builds; `yifuwuqi` catches nighttime fallback builds     | B2, E, A′, A                                  | Set `remoteBuilder = false` on the Minecraft host                      |

## Next step

Choose between **B2** (new 32 GB Zen 4 host + `yitaishi` +32 GB), **E** (new
32 GB Zen 4 host + `yifuwuqi` +32 GB SO-DIMM), or **A′** (new 32 GB Zen 4 host
first), and pick **SER8** (quieter) vs **GMKtec K8** (dual 2.5GbE, TLC SSD) plus
the new hostname. Then author `docs/src/plans/<topic>-plan.md` (Objective /
Current state / Decisions / Phases / Rollout order / Open questions) covering:

- delivered SKU, BIOS, memory speed (including 4-DIMM training speed on
  `yitaishi` if B2 is chosen), NIC, and SSD verification;
- NixOS bootstrap, Vulkan (`gfx1103`), Tailscale, Attic, `ai-ssh`, and
  Prometheus/Loki onboarding (including `yitaishi`);
- Gemma `llama-bench` and real-world Minecraft MSPT/TPS baselines, followed by a
  two-hour combined load check with zero OOM kills, GPU/NIC resets, thermal
  throttling, or >40 ms p95 MSPT;
- a tested Minecraft backup restore with capped `zstd` threads.

A successful flake evaluation does not establish GPU, thermal, storage, network,
or Minecraft tick behavior.

## Reproducing the measurements

PromQL against `yifuwuqi`'s Prometheus (`127.0.0.1:24090`):

```promql
count_over_time((min_over_time(node_memory_MemAvailable_bytes{host="yifuwuqi"}[1h]) < 1073741824)[1d:1h])
count_over_time(((rate(node_pressure_cpu_waiting_seconds_total{host="yifuwuqi"}[1m]) > 0.10) and on(host) (node_memory_MemAvailable_bytes{host="yifuwuqi"} > 2147483648))[30d:1m])
max_over_time(((rate(node_disk_write_time_seconds_total{host="yifuwuqi",device="nvme0n1"}[1m]) / clamp_min(rate(node_disk_writes_completed_total{host="yifuwuqi",device="nvme0n1"}[1m]), 1)) and on(host) (node_memory_MemAvailable_bytes{host="yifuwuqi"} > 2147483648))[30d:1m])
topk(15, max_over_time((sum by (groupname) (rate(namedprocess_namegroup_cpu_seconds_total{host="yifuwuqi"}[1m])))[12d:1m]))
max_over_time((sum by (groupname) (namedprocess_namegroup_memory_bytes{host="yifuwuqi",memtype=~"resident|swapped"}))[12d:5m])
```

Host facts: DIMM layout from `udevadm info --query=property /sys/devices/virtual/dmi/id`
(on `yitaishi`, `ai-ssh yitaishi cat /run/udev/data/+dmi:id`), drive model from
`lsblk -d -o NAME,SIZE,MODEL`, power-on history from
`ai-ssh yitaishi journalctl --list-boots`, and generation speed from
`llama-server` timing lines in `journalctl -u llama-cpp.service`.

## Sources

### Repository and runtime

- `hosts/yifuwuqi/`, `hosts/yitaishi/`
- `modules/addresses.nix`, `modules/distributed-builds.nix`
- `modules/services/ai/llama-cpp.nix`, `modules/services/ai/models.nix`,
  `modules/services/ai/sd-cpp.nix`, `modules/services/ai/sillytavern.nix`
- `modules/services/proxy-vhosts.nix`, `modules/services/nginx-proxy.nix`,
  `modules/services/forgejo-runner.nix`
- `users/programs/opencode.nix`, `users/home/workd.nix`, `ci/build.sh`,
  `nix/deploy.nix`
- `../mc-aset-loveland/compose.yaml`, `server.properties`, `c2me.toml`,
  `DistantHorizons.toml`, `scripts/backup.sh`, `nix/module.nix`,
  `docs/src/plans/nix-migration-plan.md`
- `docs/src/services/ai-rocm.md`, `docs/src/services/arr-stack.md`,
  `docs/src/services/monitoring.md`

### Hardware and software

- [AMD Ryzen 7 H 255 specifications](https://www.amd.com/zh-cn/products/processors/laptop/ryzen/200-series/amd-ryzen-7-h-255.html)
- [AMD Ryzen 7 7700X specifications](https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-7-7700x.html)
- [AMD Ryzen AI Max+ 395 specifications](https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html)
- [Beelink SER8 review (Notebookcheck)](https://www.notebookcheck.net/Beelink-SER8-PC-review-Mac-Mini-inspired-design-with-an-AMD-Ryzen-7-8845HS.857066.0.html)
  and [8745HS teardown notes](https://arstechnica.com/civis/threads/mini-pc-review-beelink-ser8.1504478/)
- [GMKtec NucBox K8 review (Liliputing)](https://liliputing.com/gmktec-nucbox-k8-review-amd-ryzen-7-8845hs-is-a-nuc-like-mini-pc/)
- [Beelink SER9 MAX specifications](https://www.bee-link.com/products/beelink-ser9-max-amd-ryzen-7-h-255)
  and [US price history](https://deal.ai/p/beelink-ser9-max-mini-pc-ryzen-7-h255-64gb-ddr5-ram-1tb-ssd-6ae766a597384b3ce4f41268)
- [Beelink EQR6 specifications](https://www.newegg.com/beelink-eqr-series-barebone-systems-mini-pc-eqr6-6900hx/p/2SW-0012-001X0)
  and [review](https://www.neowin.net/reviews/beelink-erq6-review-its-an-office-class-ryzen-9-6900hx-mini-pc-with-24gb-memory/)
- [Crucial P3 Plus QLC write-cache tests (ComputerBase)](https://www.computerbase.de/artikel/storage/crucial-p3-plus-ssd-test.81563/)
  and [PC Gamer](https://www.pcgamer.com/crucial-p3-plus-2tb-review-benchmark-performance/)
- [llama.cpp: Gemma 4 26B on Radeon 780M](https://github.com/ggml-org/llama.cpp/discussions/24222)
- [Radeon 780M high-memory community benchmarks](https://www.reddit.com/r/LocalLLaMA/comments/1qaap05/benchmarks_of_radeon_780m_igpu_with_shared_128gb/)
- [NixOS llama.cpp backends](https://wiki.nixos.org/wiki/Llama-cpp)
- [Receita Federal import-tax calculation](https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/manuais/remessas-postal-e-expressa/preciso-pagar-impostos-nas-compras-internacionais/quanto-pagarei-de-imposto)
- [Receita Federal simplified-remittance scope](https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/manuais/remessas-postal-e-expressa/preciso-pagar-impostos-nas-compras-internacionais/quais-sao-os-impostos-devidos)

Market sources are linked from the [market table](#market-data-2026-11-16).
