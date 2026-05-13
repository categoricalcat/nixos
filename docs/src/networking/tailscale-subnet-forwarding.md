# Tailscale Subnet Forwarding

This runbook documents the forwarding issue that appeared when reaching
`yifuwuqi` through `yirukou`'s advertised Tailscale subnet route.

## Symptom

From a tailnet client, direct access to `yifuwuqi` over Tailscale worked:

```sh
nc -zv 100.69.0.6 3333
```

The same service over the LAN address timed out:

```sh
nc -zv 10.42.0.2 3333 -w 4
```

The two addresses are the same destination host:

- `100.69.0.6`: `yifuwuqi` Tailscale address
- `10.42.0.2`: `yifuwuqi` LAN address

That points away from the service listener and toward subnet-router forwarding
on `yirukou`.

## Root Cause

`yirukou` advertised `10.42.0.0/24` through Tailscale, but the forward chain only
allowed internal interfaces to leave through WAN. It did not explicitly allow
`tailscale0 -> br0` forwarding for the LAN subnet.

AdGuard Home on `yifuwuqi` was already listening on all IPv4 addresses:

```nix
services.adguardhome = {
  host = "0.0.0.0";
  port = 3333;
  settings.http.address = "0.0.0.0:3333";
};
```

## Fix

`hosts/yirukou/networking/firewall.nix` now allows Tailscale-routed clients to
enter the LAN and allows established LAN replies back out through Tailscale:

```nix
extraForwardRules = ''
  iifname { ${wanSet} } ct state invalid drop comment "drop invalid wan forward"
  iifname { ${internalSet} } oifname { ${wanSet} } accept comment "internal to wan"
  iifname "${config.services.tailscale.interfaceName}" oifname "${lan.interface}" ip daddr ${lan.ipv4.cidr} accept comment "tailscale to lan subnet"
  iifname "${lan.interface}" oifname "${config.services.tailscale.interfaceName}" ip saddr ${lan.ipv4.cidr} ct state established,related accept comment "lan replies to tailscale subnet clients"
'';
```

Rendered for the current address plan, this means:

```nft
iifname "tailscale0" oifname "br0" ip daddr 10.42.0.0/24 accept
iifname "br0" oifname "tailscale0" ip saddr 10.42.0.0/24 ct state established,related accept
```

## Validation

Evaluate the router config:

```sh
nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.yirukou.config.networking.firewall.extraForwardRules --raw
```

After switching `yirukou`, test from a tailnet client:

```sh
nc -zv 10.42.0.2 3333 -w 4
curl -I http://10.42.0.2:3333/
```

If it still times out, inspect live state on `yirukou`:

```sh
sudo nft list ruleset
tailscale status
tailscale debug prefs
```

Also confirm that Tailscale has accepted the advertised `10.42.0.0/24` route in
the admin console.

## Source Files

- `hosts/yirukou/networking/firewall.nix`
- `hosts/yirukou/services.nix`
- `modules/services/tailscale.nix`
- `modules/services/adguardhome.nix`
