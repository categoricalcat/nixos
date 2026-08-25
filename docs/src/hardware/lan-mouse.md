# Software KVM (Lan Mouse)

To share a single keyboard and mouse across multiple desktop machines, the fleet uses `lan-mouse` (`modules/services/lan-mouse.nix`).

Currently, this is configured between `yitaishi` (desktop) and `yixiaoqing` (laptop).

## Configuration

*   **`yitaishi`** acts as the host/server for its right-side boundary. When the cursor moves off the right edge of `yitaishi`'s screen, it transfers to `yixiaoqing`.
*   **`yixiaoqing`** acts as the host/server for its left-side boundary. When the cursor moves off the left edge, it transfers back to `yitaishi`.

Connections are bound to Tailscale interfaces (`100.x.x.x`), ensuring the KVM traffic is encrypted and works seamlessly even if the laptop moves to a different physical network, provided both nodes are connected to the Tailnet.
