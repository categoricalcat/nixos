# Troubleshooting USB Boot Delays

## The Symptom
The system hangs for 1 minute and 30 seconds during boot, specifically during the `initrd` switch-root phase. The console output shows:
```
A stop job is running for Rule-based Manager for Device Events and Files (systemd-udevd.service)
```

## The Investigation & Root Cause

This delay occurs because `systemd-udevd` refuses to shut down when systemd attempts to pivot from the `initrd` into the real root filesystem. `udevd` gets stuck for several hardware and configuration reasons:

1. **Dead USB Hardware (The Primary Culprit)**
   A physically failing USB device (in our case, a dead Bluetooth adapter) failed to respond to the kernel's initial USB descriptor read. The kernel log (`journalctl -k -b -1`) showed:
   ```
   kernel: usb 3-8: device descriptor read/64, error -110
   ```
   `error -110` translates to `ETIMEDOUT`. Because the kernel's USB hub driver (`xhci_hcd`) blocks sequentially while retrying the descriptor read for 30-45 seconds, it wedges the entire USB subsystem. `udevd` gets stuck waiting for the kernel, which in turn blocks the boot process.

2. **Global USB Autosuspend Disabled**
   Setting `usbcore.autosuspend=-1` globally prevents the kernel from putting *any* idle or failing devices to sleep. While this is great for ensuring zero-latency mouse wake-ups, it inadvertently forced the kernel to obsessively keep the dead Bluetooth port fully powered and retry the failed probe indefinitely, locking up the boot.

3. **Infinite `udev` Loops (A Configuration Trap)**
   Writing to sysfs power attributes can trigger new `change` events. A rule like this:
   ```udev
   ACTION=="add|change", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
   ```
   ...creates an infinite loop. The rule writes to `power/control`, which triggers a `change` event, which triggers the rule again. `udevd` becomes permanently busy processing these events and refuses to exit.

## How to Identify the Broken Hardware

Because the broken device fails the descriptor read, the system doesn't know its Vendor ID or Product ID. To find it:
1. Run `lsusb` to see all successfully enumerated devices.
2. Cross-reference the list with the physical devices plugged into the PC.
3. Whatever is plugged in but **missing** from the `lsusb` list is the dead device.
4. Alternatively, unplug devices one by one while watching `journalctl -k -f` until you see a `USB disconnect` message for the problematic port (e.g., `usb 3-8`).

## The Fixes

1. **Move or Replace the Dead Hardware:**
   Moving the quirky Bluetooth adapter from a secondary motherboard USB 2.0 port to a direct CPU-linked USB 3.0/3.2 port completely bypassed the `-110` initialization bug. If moving it doesn't work, the hardware is dead and must be replaced.

2. **Remove Recursive Udev Rules:**
   Never write to `power/control` triggering on `add|change`. Limit it to `ACTION=="add"` or explicitly check the current value before writing to prevent infinite loops.

3. **Add a Safety Net Timeout:**
   To prevent future hardware failures from hanging the boot for 1.5 minutes, you can safely drop the `initrd` stop job timeout. Since this stop job only happens *after* the root drive is successfully mounted, forcefully killing a stuck `udevd` here has no negative impact:
   ```nix
   # In configuration.nix or boot.nix
   boot.initrd.systemd.settings.Manager = {
     DefaultTimeoutStopSec = "10s";
   };
   ```
