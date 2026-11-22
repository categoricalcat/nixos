#!/usr/bin/env bash
# Standard server/laptop disk layout (bootstrap-runbook.md §2.1): GPT with a
# 1 GiB ESP (BOOT), 32 GiB swap (SWAP), and an ext4 root (ROOT) carrying
# boot/ and persist/ inside it. Destructive: erases <device> wholesale; it
# refuses non-whole-disk nodes and any disk with a mounted filesystem or
# active swap in its topology (partitions and LUKS/LVM layers included, so
# the running-root disk is always refused).
# The DR drill (secrets/test.nix) runs this exact command, so runbook and
# rehearsal cannot drift.
# usage: bootstrap-disk <device> [mountpoint=/mnt]
set -euo pipefail

device="${1:-}"
mountpoint="${2:-/mnt}"

if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (su -)." >&2
  exit 1
fi

if [ "$device" = "" ] || [ ! -b "$device" ]; then
  echo "Usage: bootstrap-disk <device> [mountpoint=/mnt] — <device> must be a block device." >&2
  exit 1
fi

# /dev/disk/by-* symlinks name partitions `-partN`; derive them from the kernel name.
device="$(readlink -f "$device")"

if [ "$(lsblk -dn -o TYPE "$device")" != "disk" ]; then
  echo "Error: refusing to touch $device (must be a whole disk, not a partition/mapper/loop/raid node)." >&2
  exit 1
fi

if [ "$mountpoint" = "" ] || [ "$mountpoint" = "/" ] || { [ -e "$mountpoint" ] && mountpoint -q "$mountpoint"; }; then
  echo "Error: refusing mountpoint '$mountpoint' (must not be / or already mounted)." >&2
  exit 1
fi

# Refuse if any filesystem or swap anywhere in <device>'s topology is active —
# partitions and LUKS/LVM layers included (lsblk walks the whole stack).
# The running root is always mounted, so its disk is always refused here.
if lsblk -rn -o MOUNTPOINTS "$device" | grep -q .; then
  echo "Error: $device or a partition/layer of it is mounted or active swap." >&2
  exit 1
fi

# nvme/mmcblk-style devices need the p separator before the partition number.
case "$device" in
*[0-9]) parts="${device}p" ;;
*) parts="$device" ;;
esac
boot_part="${parts}1"
swap_part="${parts}2"
root_part="${parts}3"

sgdisk -Z \
  -n 1:0:+1G -t 1:ef00 -c 1:BOOT \
  -n 2:0:+32G -t 2:8200 -c 2:SWAP \
  -n 3:0:0 -t 3:8300 -c 3:ROOT \
  "$device"
udevadm settle

mkfs.vfat -F 32 -n BOOT "$boot_part"
mkswap -L SWAP "$swap_part"
mkfs.ext4 -F -L ROOT "$root_part"

mkdir -p "$mountpoint"
mount "$root_part" "$mountpoint"
mkdir -p "$mountpoint/boot" "$mountpoint/persist"
mount "$boot_part" "$mountpoint/boot"
swapon "$swap_part"
