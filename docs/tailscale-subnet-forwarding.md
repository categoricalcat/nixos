# Tailscale Subnet Forwarding Debug Note

## Summary

`yitaishi` could reach AdGuard Home on `yifuwuqi` through the direct
Tailscale address:

```sh
nc -zv 100.69.0.6 3333
```

but timed out when using the LAN address routed through the advertised subnet:

```sh
nc -zv 10.42.0.2 3333 -w 4
```

The two addresses are the same destination host:

- `100.69.0.6`: `yifuwuqi` Tailscale address
- `10.42.0.2`: `yifuwuqi` LAN address on `eno1`

This points away from an AdGuard listener problem and toward subnet-router
forwarding on `yirukou`.

## Relevant Config

AdGuard Home is configured to listen on all IPv4 addresses:

```nix
services.adguardhome = {
  enable = true;
  host = "0.0.0.0";
  port = 3333;

  settings.http.address = "0.0.0.0:3333";
};
```

`yifuwuqi` trusts both its LAN and Tailscale interfaces:

```nix
networking.firewall.trustedInterfaces = [
  "tailscale0"
  "eno1"
];
```

`yirukou` advertises the LAN subnet through Tailscale:

```nix
yi.tailscale = {
  routingMode = "both";
  advertiseRoutes = [ "10.42.0.0/24" ];
};
```

Before this fix, `yirukou` only allowed forwarding from internal interfaces to
WAN interfaces:

```nix
extraForwardRules = ''
  iifname { ${wanSet} } ct state invalid drop comment "drop invalid wan forward"
  iifname { ${internalSet} } oifname { ${wanSet} } accept comment "internal to wan"
'';
```

That did not explicitly allow `tailscale0 -> br0` forwarding for subnet-routed
traffic.

## Fix

`hosts/yirukou/networking/firewall.nix` now allows Tailscale subnet traffic to
leave through the LAN bridge and allows established LAN replies back to
Tailscale:

```nix
extraForwardRules = ''
  iifname { ${wanSet} } ct state invalid drop comment "drop invalid wan forward"
  iifname { ${internalSet} } oifname { ${wanSet} } accept comment "internal to wan"
  iifname "${config.services.tailscale.interfaceName}" oifname "${lan.interface}" ip daddr ${lan.ipv4.cidr} accept comment "tailscale to lan subnet"
  iifname "${lan.interface}" oifname "${config.services.tailscale.interfaceName}" ip saddr ${lan.ipv4.cidr} ct state established,related accept comment "lan replies to tailscale subnet clients"
'';
```

Rendered for `yirukou`, this becomes:

```nft
iifname { "enp7s0", "enp6s0" } ct state invalid drop comment "drop invalid wan forward"
iifname { "br0", "enp2s0.42", "tailscale0" } oifname { "enp7s0", "enp6s0" } accept comment "internal to wan"
iifname "tailscale0" oifname "br0" ip daddr 10.42.0.0/24 accept comment "tailscale to lan subnet"
iifname "br0" oifname "tailscale0" ip saddr 10.42.0.0/24 ct state established,related accept comment "lan replies to tailscale subnet clients"
```

## Validation

Local evaluation passed:

```sh
nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
```

The generated `extraForwardRules` were also rendered successfully:

```sh
nix eval .#nixosConfigurations.yirukou.config.networking.firewall.extraForwardRules --raw
```

Attempted deployment from `yitaishi`:

```sh
nixos-rebuild switch --flake .#yirukou --target-host yirukou --use-remote-sudo
```

The system build completed, but copying/switching failed because SSH to
`yirukou` on port 22 was refused:

```text
ssh: connect to host yirukou port 22: Connection refused
```

Retrying with the configured SSH port also failed:

```sh
NIX_SSHOPTS='-p 24212' nixos-rebuild switch --flake .#yirukou --target-host yi@yirukou --use-remote-sudo
```

```text
ssh: connect to host yirukou port 24212: Connection refused
```

Direct checks from this machine also timed out:

```sh
nc -zv 10.42.0.1 24212 -w 4
nc -zv 100.69.0.1 24212 -w 4
nc -zv 10.42.0.2 3333 -w 4
```

So the config is updated and evaluates, but live validation still requires
reaching `yirukou` and switching it.

## Follow-Up

After `yirukou` is reachable, switch the router config and retest:

```sh
NIX_SSHOPTS='-p 24212' nixos-rebuild switch --flake .#yirukou --target-host yi@10.42.0.1 --use-remote-sudo
nc -zv 10.42.0.2 3333 -w 4
curl -I http://10.42.0.2:3333/
```

If `10.42.0.2:3333` still times out after switching `yirukou`, inspect live
forwarding on the router:

```sh
sudo nft list ruleset
tailscale status
tailscale debug prefs
```
