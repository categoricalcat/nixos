# Dev Certificates

`module.nix` (`yifuwuqi`, `yitaishi`, `yixiaoqing`) trusts one name-constrained
dev CA host-wide (`SSL_CERT_DIR` + `/etc/ssl/certs/4ce7bcbb.0` for OpenSSL/Go,
`NODE_EXTRA_CA_CERTS` for Node, Chrome policy where Chromium is enabled) and
shares the leaf key (`0640 root:devcert`) with `yi` and `workd`. Missing files
are skipped until `/persist/keys/dev/` exists.

The CA carries critical `nameConstraints` (`[domain ...]` plus `localhost`,
`yifuwuqi.lan`, `127.0.0.0/8`, `::1/128`) and discards its private key
immediately after signing the 397-day leaf.

## Mint / Renew

```bash
# as root (su -) on yifuwuqi:
dev-certs-setup [domain ...]

for h in yitaishi yixiaoqing; do
  ssh "$h" "install -d -m 0755 -o root -g root /persist/keys/dev"
  scp -p /persist/keys/dev/{ca.pem,cert.pem,chrome.json,key.pem} "$h:/persist/keys/dev/"
  ssh "$h" "systemd-tmpfiles --create --prefix=/persist/keys/dev"
done
```
