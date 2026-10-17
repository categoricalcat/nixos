# Gang Host Provisioning & Bootstrap Runbook

This runbook provides the definitive, step-by-step procedure for onboarding a new machine into the NixOS gang.

______________________________________________________________________

## 1. Overview of the Bootstrap Workflow

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Partition & Mount Disks (Ext4 / Btrfs + /persist tree)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 2. Run ./users/scripts/setup-sops.sh <hostname> (as root)   │
│    ├── Host ED25519 SSH Key -> /persist/keys/ssh            │
│    ├── User Mesh Key        -> ~/.ssh/id_ed25519            │
│    ├── User Git Key         -> ~/.ssh/git_ed25519           │
│    └── AI Restricted Key    -> ~/.ssh/id_ai_ed25519         │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 3. Register Public Keys in secrets/keys.nix                 │
│    └── Map host addresses & roles in modules/addresses.nix  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 4. Re-generate .sops.yaml, Rekey & Sync Secrets (as root)   │
│    ./users/scripts/setup-sops.sh && sops updatekeys -y ...  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 5. Deploy Initial NixOS System Closure (as root)            │
│    nh os switch (local) or deploy .#<hostname> (remote)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 6. Execute Post-Deploy Service Initializations              │
│    (Attic cache, Forgejo, Tailscale, Samba smbpasswd)       │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Step 1: Disk Partitioning & Filesystem Layout

### 2.1 Standard Server / Laptop Layout (Ext4)

```bash
# 1. Partition disk with GPT (ESP 1GB, Swap, Ext4 Root)
sgdisk -Z /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:BOOT /dev/nvme0n1
sgdisk -n 2:0:+32G -t 2:8200 -c 2:SWAP /dev/nvme0n1
sgdisk -n 3:0:0 -t 3:8300 -c 3:ROOT /dev/nvme0n1

# 2. Format filesystems
mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p1
mkswap -L SWAP /dev/nvme0n1p2
mkfs.ext4 -L ROOT /dev/nvme0n1p3

# 3. Mount targets
mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{boot,persist}
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2
```

### 2.2 Workstation Layout (Btrfs with Subvolumes on `yitaishi`)

```bash
mkfs.btrfs -L ROOT /dev/nvme0n1p3
mount /dev/nvme0n1p3 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o subvol=@,noatime,compress=zstd /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{boot,home,persist}
mount -o subvol=@home,noatime,compress=zstd /dev/nvme0n1p3 /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
```

______________________________________________________________________

## 3. Step 2: Key & Root Password Provisioning (`setup-sops.sh`)

Run the automated key provisioning script as `root` (`su -`):

```bash
# Clone the repository
git clone https://github.com/categoricalcat/nixos /mnt/home/yi/the.files/nixos

# Run key generator for the target host (as root)
cd /mnt/home/yi/the.files/nixos
./users/scripts/setup-sops.sh <hostname>
```

This script deterministically generates:

1. `/persist/keys/ssh/ssh_host_ed25519_key` (The host's SSH and SOPS age identity, `0600 root:root`)
1. `/root/.config/sops/age/keys.txt` (Derived host age private key for `root`)
1. `~yi/.ssh/id_ed25519` (User inter-host mesh SSH key, passphrase-less)
1. `~yi/.ssh/git_ed25519` (Git signing & commit key)
1. `~yi/.ssh/id_ai_ed25519` (Restricted `ai-ssh` read-only key)

### Client Root Password Seed (`yitaishi` / `yixiaoqing`)

Because `sudo` is disabled gang-wide and `yi` is not in `wheel`, interactive client machines (`yitaishi`, `yixiaoqing`) elevate locally via `su -` backed by `/persist/keys/passwords/root` (while servers lock local root passwords and accept key-based `ssh root@<server>` from client root). On a new client host, seed `/persist/keys/passwords/root` as `root`:

```bash
install -d -m 0700 -o root -g root /persist/keys/passwords
mkpasswd -m yescrypt > /persist/keys/passwords/root
chmod 0600 /persist/keys/passwords/root
```

*(User passwords for `yi` and `workd` are mutable in `/etc/shadow`; set them after boot with `passwd yi` as root.)*

______________________________________________________________________

## 4. Step 3: Registering Keys & Addresses

Open `secrets/keys.nix` on your workstation, paste the generated machine block,
and add the hostname to the `keyed` list:

```nix
# secrets/keys.nix
<hostname> = {
  host = {
    ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
    age = "age1...";
  };
  yi.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  ai.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  allow = {
    root = rootAdmins;
    yi = [ ];
    ai = aiAgent;
  };
};
```

Open `modules/addresses.nix` and add the host's networking parameters (IPs, MAC, SSH port, nixBuild specs).

______________________________________________________________________

## 5. Step 4: Rekeying Secrets

As `root` (`su -`) on an existing configured host, regenerate `.sops.yaml` with the new host's age recipient, rekey `secrets/secrets.yaml`, and sync `/persist/keys/sops/secrets.yaml`:

```bash
su -
cd /home/yi/the.files/nixos

# 1. Regenerate .sops.yaml from secrets/keys.nix
./users/scripts/setup-sops.sh

# 2. Rekey the encrypted secrets file for all host age recipients
sops updatekeys -y secrets/secrets.yaml

# 3. Sync the rekeyed file to /persist/keys/sops/secrets.yaml (0600 root:root)
./users/scripts/setup-sops.sh
```

______________________________________________________________________

## 6. Step 5: Initial Installation & Deployment

```bash
# On a fresh installation (as root):
nixos-install --flake .#<hostname> --root /mnt

# On an existing client system (as root via su -):
su -
nh os switch /home/yi/the.files/nixos

# Remote deployment to a server (as root via su -):
su -
cd /home/yi/the.files/nixos
deploy .#<hostname>
```

______________________________________________________________________

## 7. Step 6: Post-Deployment Service Initialization

### 7.1 Attic Binary Cache (on `yifuwuqi`)

```bash
# 1. Login to Attic server
attic login local http://127.0.0.1:24203 <admin-token>

# 2. Create the default binary cache
attic cache create yi --public --priority 38

# 3. Verify watch-store and closure-keeper units
systemctl status attic-watch-store.service
systemctl status attic-closure-keeper.timer
```

### 7.2 Forgejo Git Server (on `yifuwuqi`, as `root`)

```bash
# 1. Create the primary admin account
runuser -u forgejo -- forgejo admin user create \
  --admin \
  --username yi \
  --email admin@fufu.land \
  --password <temporary-password>

# 2. Create the Forgejo Actions runner token
# Place token into SOPS (as root): sops set secrets/secrets.yaml '["tokens"]["forgejo-runner"]' "<token>"
```

### 7.3 Samba User Password (on `yifuwuqi`, as `root`)

```bash
smbpasswd -a yi
```

### 7.4 Tailscale Network Authentication (as `root`)

```bash
# Authenticate node to tailnet
tailscale-up
```

______________________________________________________________________

## 8. Source Files

- `users/scripts/setup-sops.sh`
- `secrets/keys.nix`
- `secrets/generate-sops-yaml.nix`
- `modules/addresses.nix`
