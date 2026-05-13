# Fleet Documentation

This book documents the maintained parts of the NixOS fleet.

## Hosts

| Host | Role | Notes |
| --- | --- | --- |
| `yirukou` | router, DNS, reverse proxy, monitoring parent | Owns the `10.42.0.0/24` LAN and Tailscale subnet routing. |
| `yifuwuqi` | services and AI host | Runs hosted services, Netdata child mode, and `llama-swap`. |
| `yitaishi` | desktop and AI RPC worker | Exposes the RX 7900 XTX over Tailscale for `llama.cpp` RPC. |
| `yixiaoqing` | laptop | General client host. |
| `yichuang` | WSL host | Development environment. |

## Source Of Truth

The docs are intentionally handwritten, but the data should come from the Nix
configuration:

- Host addresses and network roles: `modules/addresses.nix`
- Router networking: `hosts/yirukou/networking.nix` and `hosts/yirukou/networking/`
- Shared service modules: `modules/services/`
- Per-host service enablement: `hosts/*/services.nix`

Planning documents should not live in this book. If a plan contains something
that is still useful, move the current-state fact or runbook here and delete
the plan.
