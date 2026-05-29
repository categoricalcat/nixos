# AI And ROCm

This page documents the current ROCm-backed local inference setup and the
debugging lessons that matter for future changes.

## Current Topology

`yifuwuqi` runs `llama-swap` on port `11434`.

`yitaishi` runs `llama-rpc-server` on its Tailscale IP at TCP `50052`, exposing
the RX 7900 XTX as a remote `llama.cpp` worker.

`modules/services/ai/models.nix` is the model registry used by:

- `modules/services/ai/llama-swap.nix`
- `users/programs/opencode.nix`

## yifuwuqi

`hosts/yifuwuqi/services.nix` enables `services.llama-swap-amdgpu` with:

- ROCm target `gfx1035`
- `HSA_OVERRIDE_GFX_VERSION=10.3.0`
- RPC peer set to `yitaishi`'s Tailscale IP on port `50052`
- `tensorSplit = "1,0"` so RPC-tagged models place all tensors on the remote
  worker instead of bottlenecking on the local APU

The local Radeon 680M still handles non-RPC models.

## yitaishi RPC Worker

`hosts/yitaishi/services.nix` enables only the RPC worker:

- ROCm target `gfx1100`
- `uma = false`
- listen address from the address registry
- port `50052`
- firewall open on `tailscale0` for TCP `50052`
- exposed RPC device restricted to `ROCm0`

The worker allows both common DRM node layouts:

- `/dev/dri/card0`
- `/dev/dri/renderD128`
- `/dev/dri/card1`
- `/dev/dri/renderD129`

That avoids coupling the dGPU worker to the APU numbering observed on
`yifuwuqi`.

## ROCm Service Sandbox

The important historical bug was not the `llama.cpp` build itself. ROCm worked
when `llama-server` was run directly, but failed inside the systemd service
sandbox.

The fix is to grant the actual character devices, not just the `/dev/dri`
directory:

```nix
DeviceAllow = [
  "/dev/kfd rw"
  "/dev/dri/card0 rw"
  "/dev/dri/renderD128 rw"
];
```

The module now builds this list from:

- `/dev/kfd`
- `services.llama-swap-amdgpu.drmDevices`

Both `llama-swap` and `llama-rpc-server` reuse the same ROCm sandbox overrides:

- `SupplementaryGroups = [ "video" "render" ]`
- `MemoryDenyWriteExecute = false`
- `PrivateUsers = false`
- `PrivateDevices = false`
- `SystemCallFilter = [ ]`
- explicit `DeviceAllow` entries

## Debug Probes

The debug probe remains intentionally present because it is the fastest way to
tell whether ROCm is visible inside the exact service sandbox.

For `llama-swap` on `yifuwuqi`:

```text
/var/log/llama-swap-dbg2/list-devices.log
/var/log/llama-swap-dbg2/server.log
```

For `llama-rpc-server` on `yitaishi` with `DynamicUser = true`:

```text
/var/log/private/llama-rpc-server/list-devices.log
```

Expected successful probe examples include:

```text
Available devices:
  ROCm0: AMD Radeon 680M
```

or:

```text
Available devices:
  ROCm0: AMD Radeon RX 7900 XTX
```

## btop ROCm Support

The system `btop` package must be built with ROCm support to show AMD GPU data:

```nix
(btop.override { rocmSupport = true; })
```

Without this override, GPU data can be absent even when ROCm inference works.

## Validation

On `yifuwuqi`:

```sh
systemctl status llama-swap
journalctl -u llama-swap
cat /var/log/llama-swap-dbg2/list-devices.log
```

On `yitaishi`:

```sh
systemctl status llama-rpc-server
journalctl -u llama-rpc-server
cat /var/log/private/llama-rpc-server/list-devices.log
```

For RPC-tagged models, `llama-swap` should spawn `llama-server` with:

```text
--rpc <yitaishi-tailscale-ip>:50052 --tensor-split 1,0
```

If ROCm disappears after a reboot, first check the real `/dev/dri/*` numbering
and update `services.llama-swap-amdgpu.drmDevices` for that host.

## Source Files

- `modules/services/ai/llama-swap.nix`
- `modules/services/ai/models.nix`
- `hosts/yifuwuqi/services.nix`
- `hosts/yitaishi/services.nix`
- `modules/packages.nix`
