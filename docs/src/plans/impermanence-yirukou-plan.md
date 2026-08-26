# Impermanence on yirukou (Edge Router & Gateway)

## Status: PLANNED — Ready for deployment

## Objective

Deploy **impermanence** (root-on-tmpfs with selective persistent storage under `/persist`) to **`yirukou`** using a zero-repartitioning, in-place Ext4 strategy with full rollback safety.

---

## Current State

1. **Filesystem Layout**:
   - `nvme0n1p1` (1 GB): EFI System Partition (`/boot`, VFAT, UUID `7B94-F350`)
   - `nvme0n1p2` (~239 GB): Traditional persistent root (`/`, Ext4, UUID `685d4cb2-aba3-44d5-b9ba-20a9692ff385`)
   - `nvme0n1p3` (~9 GB): Dedicated Swap (`[SWAP]`, UUID `29757075-8a2d-4171-af0f-1027608f9641`)
2. **Memory & Performance**:
   - 7.8 GiB physical RAM, ~2.6 GiB active anon memory (AdGuard Home bounded by `GOMEMLIMIT=2560MiB`, Unbound, Nginx, Vector, Kea). A 2 GiB tmpfs root will consume only ~50–100 MiB of RAM since the `/nix/store` resides on disk.
3. **Repository Pre-alignment**:
   - `secrets/keys.nix` already sets `keysFolder = "/persist/keys"`.
   - `modules/services/ssh/default.nix` asserts that `${keys.paths.sshHostKey}` (`/persist/keys/ssh/ssh_host_ed25519_key`) exists before starting `sshd`.
   - `docs/src/services/secrets.md` documents: *"This repository assumes impermanence hosts keep private runtime identity under `/persist/keys`."*

---

## Decisions

### 1. Root on tmpfs (Ext4 underlying `/persist`), NOT Btrfs Reformatting
- **Decision**: Mount `/` as a 2 GiB `tmpfs` (`mode=755,size=2G`). Mount the existing Ext4 partition (`nvme0n1p2`) at `/persist` with `neededForBoot = true`. Bind-mount `/persist/nix` to `/nix`.
- **Rationale**:
  - Requires **zero repartitioning or disk formatting**.
  - Can be staged and deployed live via standard NixOS generations.
  - Full rollback safety: selecting the previous generation in `systemd-boot` immediately boots back into persistent Ext4 root without touching disk partitions.
  - Zero performance overhead; tmpfs uses negligible RAM (~50–100 MiB) because the Nix store remains on disk.

### 2. State Isolation & Persistence Module
- **Decision**: Introduce `inputs.impermanence` (`github:nix-community/impermanence`) to manage bind mounts and symlinks under `/persist`.
- **Rationale**: Clean, battle-tested declarative abstraction that mounts directories and files before systemd units start (`neededForBoot`), avoiding race conditions with system daemons.

### 3. Dual-Layout Key Staging
- **Decision**: Copy `/persist/keys` to `/keys` on `nvme0n1p2` (`sudo cp -a /persist/keys /keys`) prior to reboot.
- **Rationale**:
  - When `nvme0n1p2` is mounted at `/persist`, its top-level `/keys` directory will resolve to `/persist/keys`.
  - The old generation continues reading `nvme0n1p2:/persist/keys` if rolled back.

---

## State Inventory on `yirukou`

```text
/ (tmpfs - wiped every boot)
├── nix/                  -> bind-mount from /persist/nix
├── persist/              -> mount /dev/nvme0n1p2 (Ext4)
│   ├── keys/             -> SSH host key & SOPS payload (mapped from nvme0n1p2:/keys)
│   ├── etc/machine-id    -> Persisted machine ID
│   ├── var/lib/
│   │   ├── acme/         -> Let's Encrypt wildcard certificates (*.fufu.land)
│   │   ├── tailscale/    -> Tailscale node key & state
│   │   ├── kea/          -> DHCPv4 lease database (dhcp4.leases)
│   │   ├── AdGuardHome/  -> DNS blocklist cache & runtime data
│   │   ├── unbound/      -> DNSSEC root trust anchor (root.key)
│   │   ├── goaccess/     -> Real-time analytics database
│   │   ├── chrony/       -> Hardware clock frequency drift file
│   │   ├── vector/       -> Journal cursor offset tracking
│   │   ├── nixos/        -> Declarative user/group state mappings
│   │   └── systemd/coredump
│   ├── var/log/          -> Persistent systemd journal & Nginx access logs
│   └── home/yi/
│       ├── .ssh/         -> User mesh, git, and ai SSH keys
│       ├── .config/sops/ -> Derived age identity keys.txt
│       ├── .zsh_history  -> Shell history
│       └── the.files/    -> Local clone of flake repository
└── [everything else]     -> Volatile RAM (tmp, run, etc, var/cache, root)
```

---

## Phases

### Phase 1 — Flake & Module Updates

1. **Add Impermanence Input** to `flake.nix`:
   ```nix
   impermanence = {
     url = "github:nix-community/impermanence";
     inputs.nixpkgs.follows = "nixpkgs";
     inputs.home-manager.follows = "home-manager";
   };
   ```
2. **Wire Module** in `flake.nix`:
   ```nix
   modules = [
     inputs.impermanence.nixosModules.impermanence
     sops-nix.nixosModules.sops
     home-manager.nixosModules.home-manager
     ./hosts/yirukou/configuration.nix
   ];
   ```
3. **Create `hosts/yirukou/impermanence.nix`**:
   ```nix
   { ... }:
   {
     environment.persistence."/persist" = {
       hideMounts = true;
       directories = [
         # Core Network & Ingress Services (Tier 1)
         "/var/lib/acme"
         "/var/lib/tailscale"
         "/var/lib/kea"

         # DNS, Web Analytics & Clock Drift (Tier 2)
         "/var/lib/AdGuardHome"
         "/var/lib/unbound"
         "/var/lib/goaccess"
         "/var/lib/chrony"

         # System, Observability & Core Dumps (Tier 2)
         "/var/log"
         "/var/lib/nixos"
         "/var/lib/vector"
         "/var/lib/systemd/coredump"
       ];
       files = [
         "/etc/machine-id"
       ];
       users.yi = {
         directories = [
           ".ssh"
           ".config/sops"
           "the.files"
         ];
         files = [
           ".zsh_history"
         ];
       };
       users.root = {
         directories = [
           ".config/sops"
         ];
         files = [
           ".zsh_history"
         ];
       };
     };
   }
   ```
4. **Update `hosts/yirukou/hardware.nix`**:
   ```nix
   fileSystems = {
     "/" = {
       device = "none";
       fsType = "tmpfs";
       options = [
         "defaults"
         "size=2G"
         "mode=755"
       ];
     };

     "/persist" = {
       device = "/dev/disk/by-uuid/685d4cb2-aba3-44d5-b9ba-20a9692ff385";
       fsType = "ext4";
       neededForBoot = true;
     };

     "/nix" = {
       device = "/persist/nix";
       fsType = "none";
       options = [ "bind" ];
       neededForBoot = true;
     };

     "/boot" = {
       device = "/dev/disk/by-uuid/7B94-F350";
       fsType = "vfat";
       options = [
         "fmask=0077"
         "dmask=0077"
       ];
     };
   };
   ```
5. **Import in `hosts/yirukou/configuration.nix`**:
   Add `./impermanence.nix` to imports.

### Phase 2 — Pre-Migration Disk Staging (on `yirukou`)

1. Copy `/persist/keys` to `/keys` on `yirukou`:
   ```bash
   sudo cp -a /persist/keys /keys
   ```
2. Verify that state directories exist on `nvme0n1p2` (`/var/lib/{acme,tailscale,kea,AdGuardHome,unbound,goaccess,vector,chrony}`, `/etc/machine-id`, `/home/yi`).

### Phase 3 — Build, Stage Boot Generation & Reboot

1. Lock flake inputs and dry build:
   ```bash
   nix flake lock --update-input impermanence
   nix flake check
   nixos-rebuild dry-build --flake .#yirukou
   ```
2. Build and set bootloader generation (do NOT `switch`):
   ```bash
   sudo nixos-rebuild boot --flake .#yirukou
   ```
3. Reboot:
   ```bash
   sudo reboot
   ```

---

## Rollout Order

1. **Staging**: Execute `sudo cp -a /persist/keys /keys` on `yirukou`.
2. **Code**: Edit `flake.nix`, `hosts/yirukou/hardware.nix`, `hosts/yirukou/impermanence.nix`, `hosts/yirukou/configuration.nix`.
3. **Build**: Run `nix flake lock --update-input impermanence` and dry-build to verify closure.
4. **Deploy**: Run `sudo nixos-rebuild boot --flake .#yirukou` on `yirukou`.
5. **Reboot**: Run `sudo reboot`.
6. **Verify**: Execute verification checklist.

---

## Verification per Host

Following reboot on the impermanence generation:

- [ ] `findmnt /` shows `tmpfs`; `findmnt /persist` shows `/dev/nvme0n1p2`; `findmnt /nix` shows bind mount `/persist/nix`.
- [ ] `ip route` shows default route via active WAN; `wan-check` succeeds; LAN devices have internet connectivity.
- [ ] `systemctl status kea-dhcp4-server` active; active leases retained in `/var/lib/kea/dhcp4.leases`.
- [ ] `systemctl status adguardhome unbound` active; `dig @10.42.0.1 google.com` resolves; DNSSEC validation passes.
- [ ] `systemctl status nginx` active; `/var/lib/acme/fufu.land/fullchain.pem` valid without requesting a new certificate.
- [ ] `tailscale status` confirms node is online, advertising `10.42.0.0/24` subnet and exit node without re-authentication.
- [ ] `sops-install-secrets` succeeded; `ssh root@yirukou` / `ai-ssh yirukou` connects with existing host fingerprint.
- [ ] **Canary Persistence Test**:
  ```bash
  ssh root@yirukou "touch /root/volatile-test && touch /persist/persistent-test"
  sudo reboot
  # Confirm /root/volatile-test is absent and /persist/persistent-test is present
  ```

---

## Open Questions

- None — all architectural decisions, filesystem paths, service directories, and migration mechanics have been verified.
