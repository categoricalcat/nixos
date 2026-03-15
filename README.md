# 伊的flake

my allegedly pure configs

## the stuff
- **yitaishi**: main desktop
- **yixiaoqing**: laptop
- **yifuwuqi**: monolith server
- **yichuang**: wsl

## secrets (sops-nix)

generate the age key from the host's ssh key:

```bash
nix-shell -p ssh-to-age --run \
  'ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /etc/nixos/secrets/key.txt'
  
# public key (for .sops.yaml):
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

see `.sops.example.yaml` and `secrets/.secrets.example.yaml` for the expected formats.