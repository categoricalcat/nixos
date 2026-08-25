# File Sharing (Samba)

The network shares are hosted on `yifuwuqi` using Samba and mounted as clients on `yirukou`, `yixiaoqing`, and `yichuang`.

## Bootstrap Samba User

After the first deployment, you must set the SMB password for the `yi` user interactively:

```bash
nix-shell -p samba --run "sudo smbpasswd -a yi"
```

> *See `.sops.example.yaml` and `secrets/.secrets.example.yaml` for the expected SOPS formats.*
