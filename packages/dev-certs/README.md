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

## Project copy

As `yi` or `workd`:

```bash
dev-certs-copy [folder]   # no folder writes into .
dev-certs-copy certificates
next dev --experimental-https
```

That writes `localhost.pem`, `localhost-key.pem` (`0600`), and `ca.pem` into
the folder (asking once before overwriting), and appends that folder (or
those three names, when the folder is `.`) to `.gitignore` when that file
exists. With the folder named
`certificates/`, `next dev --experimental-https` reuses
`certificates/localhost.pem` and `certificates/localhost-key.pem` with no
flags, and Node already trusts the CA host-wide via `NODE_EXTRA_CA_CERTS`
(`module.nix`). Only a differently-named folder needs the explicit paths:

```bash
next dev --experimental-https \
  --experimental-https-key myfolder/localhost-key.pem \
  --experimental-https-cert myfolder/localhost.pem
```
