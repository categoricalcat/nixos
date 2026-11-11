# File Sharing (Samba & WebDAV)

The infrastructure provides shared network storage using Samba (SMB/CIFS) for low-latency local mounts and WebDAV for HTTP-based file operations.

______________________________________________________________________

## 1. Storage Shares & Mount Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    yifuwuqi (Samba Server)                  │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │ Share: "share"          │     │ Share: "the.files"    │  │
│  │ Path: /srv/shares/share │     │ Path: /home/yi/the.files│
│  │ Read/Write: user yi     │     │ Read-Only: guest      │  │
│  └───────────▲─────────────┘     └───────────▲───────────┘  │
└──────────────┼───────────────────────────────┼──────────────┘
               │ SMB2/3 Protocol               │
               │ (LAN 10.42.0.2; Tailnet via yirukou)       │
┌──────────────┴───────────────────────────────┴──────────────┐
│                    Samba Client Gang                        │
│        (yitaishi, yixiaoqing, yirukou, yichuang)            │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │ /mnt/smb/share          │     │ /mnt/smb/the.files    │  │
│  └─────────────────────────┘     └───────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ smb-mounts-recover.timer (30s auto-recovery loop)     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Samba Server Configuration (`modules/services/samba/server.nix`)

Hosted on `yifuwuqi` using native NixOS Samba integration:

- **Access Control**: `hosts allow` accepts trusted LAN/ULA and loopback
  sources. Tailnet clients reach `10.42.0.2` through `yirukou`'s SNATed
  subnet route; the direct VPN CIDR is excluded.
- **Configured Shares**:
  - **`[share]`**: General-purpose high-capacity storage at `/srv/shares/share`. Directory permissions `0775` with `create mask = 0664` and `directory mask = 0775`.
  - **`[the.files]`**: Bind-mount of `/home/yi/the.files` (the primary dotfiles and NixOS repository root). Allows guest read access with authenticated read-write for user `yi`.
- **Security**: SMB protocol minimum version set to `SMB2_10` to disable legacy, insecure SMBv1 dialects.

______________________________________________________________________

## 3. Samba Client Automounts (`modules/services/samba/client.nix`)

Deployed across all client machines (`yitaishi`, `yixiaoqing`, `yirukou`, `yichuang`):

### 3.1 Systemd Automount Units

Mount points are created on-demand via `systemd.automounts`:

- `/mnt/smb/share`
- `/mnt/smb/the.files`

Mount options:

- `x-systemd.automount`, `x-systemd.idle-timeout=60`, `x-systemd.device-timeout=5s`, `x-systemd.mount-timeout=5s`, `noauto`, `_netdev`, `nofail`.
- Authenticates using credentials from Sops-nix (`/run/secrets/samba/credentials`).

### 3.2 Automated Mount Recovery Daemon

To handle network roaming (e.g. laptop switching between Wi-Fi and Tailscale) without stuck CIFS mounts:

- **`smb-mounts-recover.service`**: Periodically checks mount point responsiveness. If a mount becomes unreachable or enters a stale state, it forcefully unmounts (`umount -l`) and restarts the systemd mount unit.
- **`smb-mounts-recover.timer`**: Triggers the health check every **30 seconds**.

______________________________________________________________________

## 4. WebDAV Storage (`modules/services/webdav.nix`)

- **Host**: `yifuwuqi` (served at `https://webdav.aset.love`).
- **Engine**: Nginx with compiled `nginxModules.dav` extensions.
- **Root Path**: `/srv/webdav` (owned by `nginx:nginx` with mode `0775`).
- **Features**: Unlimited file upload sizes (`client_max_body_size 0`), full directory indexing, and support for all RFC 4918 WebDAV methods (`MKCOL`, `PROPFIND`, `LOCK`, `UNLOCK`, etc.).

______________________________________________________________________

## 5. File Browser (`modules/services/filebrowser.nix`)

- **Host**: `yifuwuqi`, loopback `127.0.0.1:24086`, proxied at `https://files.aset.love`.
- **Scope**: `/home/yi`, bind-mounted read-only into the service. Runs as `yi`.
- **Login**: username `yi` and SOPS `passwords/filebrowser`. That password is not the unix password.
- **Access**: download only. Dotfiles are visible; `/the.files/nixos/secrets` is denied. Symlinks that leave `/home/yi` are not followed.

______________________________________________________________________

## 6. Key Source Files

- `modules/services/samba/server.nix`
- `modules/services/samba/client.nix`
- `modules/services/webdav.nix`
- `modules/services/filebrowser.nix`
- `hosts/yifuwuqi/services.nix`
