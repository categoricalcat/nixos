# APU / ROCm Debug Report

## Overview

This file records the full debugging session for the AMD APU / ROCm issues on `yifuwuqi`.

Original symptoms:

- The AMD APU was not showing up in `btop`
- `llama-swap` / `llama-server` was not using the APU and behaved like CPU-only inference

## Bugs Found

### 1. `btop` was built without working ROCm support in the installed package set

The default `btop` package in the active system was not exposing AMD GPU data.

Final root cause:

- `btop` needed to be installed with `rocmSupport = true`
- Once rebuilt that way, the binary gained a `DT_RUNPATH` to `rocm-smi`, and `librocm_smi64.so` became loadable

Final fix:

- In `modules/packages.nix`, replaced `btop` with:

```nix
(btop.override { rocmSupport = true; })
```

### 2. `llama-swap` service sandbox could not see the actual DRM device nodes

`llama-server` could see the APU when run directly as the user, but not when started inside the `systemd` service sandbox.

Final root cause:

- `DeviceAllow = [ "/dev/dri rw" ]` was not sufficient for ROCm inside the service
- The service needed explicit access to the actual character devices:
  - `/dev/dri/card0`
  - `/dev/dri/renderD128`
  - `/dev/kfd`

Final fix:

- In `modules/services/ai/llama-swap.nix`, changed:

```nix
DeviceAllow = [
  "/dev/kfd rw"
  "/dev/dri/card0 rw"
  "/dev/dri/renderD128 rw"
];
```

## What We Tested

### Baseline checks

- Verified the machine had the AMD GPU device nodes:
  - `/dev/kfd`
  - `/dev/dri/card0`
  - `/dev/dri/renderD128`
- Verified kernel-side AMDGPU presence through `/sys/class/drm`
- Verified `llama-swap.service` was active
- Verified current user groups included `video` and `render`

### Direct `llama-server` tests

- Ran the exact `llama-server` binary directly outside the service
- Verified it could detect the APU directly:

```text
ggml_cuda_init: found 1 ROCm devices
Device 0: AMD Radeon 680M
Available devices:
  ROCm0: AMD Radeon 680M
```

This proved ROCm itself and the built `llama-cpp` binary were fundamentally working.

### Runtime GPU usage sampling

We repeatedly sampled:

- `/sys/class/drm/card0/device/mem_info_vram_used`
- `/sys/class/drm/card0/device/mem_info_gtt_used`
- `/sys/class/drm/card0/device/gpu_busy_percent`

Before the service fix, inference showed effectively no GPU use:

- VRAM nearly unchanged
- GTT nearly unchanged
- `gpu_busy_percent = 0`
- Throughput matched CPU-only behavior

After the service fix, inference showed large GPU memory usage:

- `gtt_used` jumped to about `9.29 GiB`
- `llama-server` logs showed full ROCm offload
- Token latency dropped significantly

### `btop` inspection

We checked:

- `ldd` output
- binary strings for `librocm_smi64.so`
- `readelf -d` for `RUNPATH`
- direct `dlopen` behavior against `librocm_smi64.so`

Important note:

- An early check using `patchelf --print-rpath` was wrong because `patchelf` was not installed on the host
- Later `readelf` checks confirmed the rebuilt `btop` binary had the correct `RUNPATH`

Verified final state:

- `RUNPATH` includes `rocm-smi`
- `librocm_smi64.so` loads successfully
- User confirmed the GPU now shows in `btop`

### `llama-swap` instrumentation

To get runtime evidence from inside the service, we added temporary debug instrumentation:

- `--log-file /var/log/llama-swap-dbg2/server.log`
- `--verbose`
- `LogsDirectory = "llama-swap-dbg2"`
- `LogsDirectoryMode = "0755"`
- `UMask = "0022"`

We also added:

- `ExecStartPre` probe that runs:

```text
llama-server --list-devices
```

inside the exact service sandbox and writes the result to:

```text
/var/log/llama-swap-dbg2/list-devices.log
```

This was key to proving the service sandbox behaved differently from the user shell.

### Transient `systemd-run` reproduction tests

We used `systemd-run` to reproduce the sandbox behavior outside the main service.

Findings:

- Minimal transient unit as user `yi`:
  - ROCm detection worked
- Transient unit with `DeviceAllow='/dev/kfd rw'` and `DeviceAllow='/dev/dri rw'`:
  - ROCm detection failed
- Transient unit with:
  - `DeviceAllow='/dev/kfd rw'`
  - `DeviceAllow='/dev/dri/card0 rw'`
  - `DeviceAllow='/dev/dri/renderD128 rw'`
  - ROCm detection worked again

This isolated the issue to the service's device cgroup permissions.

## Hypotheses We Tested

### Confirmed

- `btop` needed ROCm-enabled packaging
- `llama-swap` sandbox needed explicit DRM node access

### Rejected

- `HSA_OVERRIDE_GFX_VERSION=10.3.0` as the main cause
  - It changed reported gfx version (`gfx1030` vs `gfx1035`) but was not the blocker
- `-fit on` overriding `-ngl 99` as the main cause
  - This looked plausible from logs, but even with `-fit off`, the service still stayed CPU-only until the device permissions were fixed
- `/dev/kfd` Unix permissions as the main issue
  - `/dev/kfd` was already world-readable/writable enough for the intended use
- `AF_NETLINK` restriction as the main issue
  - Allowing it did not fix ROCm detection
- `DynamicUser` alone as the main issue
  - The real blocker was the device cgroup rule shape, not just the user model

## Final Runtime Evidence

### Before the fix

Inside the service sandbox probe:

```text
ggml_cuda_init: failed to initialize ROCm: no ROCm-capable device is detected
Available devices:
```

Model loading inside the service:

```text
load_tensors: layer 0 assigned to device CPU
...
load_tensors: layer 40 assigned to device CPU
```

Performance looked CPU-only:

- `predicted_per_token_ms` around `60-68 ms`

### After the fix

Inside the service sandbox probe:

```text
ggml_cuda_init: found 1 ROCm devices
Available devices:
  ROCm0: AMD Radeon 680M
```

Model loading inside the service:

```text
llama_model_load_from_file_impl: using device ROCm0 (AMD Radeon 680M)
load_tensors: layer 0 assigned to device ROCm0
...
load_tensors: offloaded 41/41 layers to GPU
```

Additional GPU evidence:

- `gtt_used` rose to about `9.29 GiB`
- token generation dropped to about `23.03 ms/token`

This confirmed real APU usage, not just device detection.

## Files Changed

### `modules/packages.nix`

- Replaced `btop` with `(btop.override { rocmSupport = true; })`
- Added `jq`

### `modules/services/ai/llama-swap.nix`

- Kept ROCm-enabled `llama-cpp`
- Added debug logging/instrumentation for the session
- Added `ExecStartPre` sandbox probe
- Changed `DeviceAllow` from the broad `/dev/dri rw` to explicit DRM nodes

### `hosts/yifuwuqi/services.nix`

- Final state keeps:

```nix
services.llama-swap-amdgpu = {
  enable = true;
  rocmTargets = [ "gfx1035" ];
  rocmOverrideGfx = "10.3.0";
};
```

## Current Status

- `btop` now shows the AMD GPU
- `llama-swap` now sees `ROCm0` inside the service sandbox
- `llama-server` now offloads all model layers to the GPU

## Temporary Debug Instrumentation Still Present

The following debug changes are still present and can be removed later once no longer needed:

- `--log-file /var/log/llama-swap-dbg2/server.log`
- `--verbose`
- `LogsDirectory = "llama-swap-dbg2"`
- `LogsDirectoryMode = "0755"`
- `UMask = "0022"`
- `ExecStartPre` sandbox probe writing `list-devices.log`

## Short Final Summary

There were two separate problems:

1. `btop` was not installed with ROCm support
2. `llama-swap`'s `systemd` device cgroup allowed `/dev/dri` as a path, but not the actual DRM character devices ROCm needs

Once `btop` was rebuilt with `rocmSupport = true` and `llama-swap` was granted explicit access to `/dev/dri/card0` and `/dev/dri/renderD128`, both the monitor and `llama-server` started using the AMD APU correctly.
