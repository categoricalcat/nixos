# Dev Certificates

The `dev-certs-generate` / `dev-certs-push` / `dev-certs-copy` CLIs ship in
`nix develop`, not in the system profile. `module.nix` (`yifuwuqi`, `yitaishi`,
`yixiaoqing`) trusts one
name-constrained dev CA host-wide (`SSL_CERT_FILE` + `SSL_CERT_DIR` +
`/etc/ssl/certs/4ce7bcbb.0` for OpenSSL/curl/Go, `NODE_EXTRA_CA_CERTS` for
Node, Chrome policy where Chromium is enabled) and shares the leaf key
(`0640 root:devcert`) with `yi` and `workd`. Missing files are skipped until
`/persist/keys/dev/` exists.

The CA carries critical `nameConstraints` (`[domain ...]` plus `localhost`,
`yifuwuqi.lan`, `127.0.0.0/8`, `::1/128`) and discards its private key
immediately after signing the 397-day leaf.

## Mint / Renew

One binary per behaviour, all sharing `lib.sh`:

```bash
# as root (su -) on yifuwuqi
dev-certs-generate                  # mint ca.pem, cert.pem, key.pem, chrome.json
dev-certs-push yitaishi yixiaoqing  # hand the current files to peers
```

`dev-certs-generate` widens the CA's name constraints with any domains you pass
(`dev-certs-generate example.test`), and overwrites the previous leaf every
time — the CA key is discarded as soon as the leaf is signed, so renewing is
just running it again. There is no separate rotate.

`dev-certs-push` runs the sequence in [`lib.sh`](lib.sh), the same code
`mtls-pki-generate` uses: one SSH connection per peer, the files as a tar stream,
then the owner and group re-applied on arrival (`devcert` / `0640` for
`key.pem`, the rest `0644 root:root`), creating the group where the declaring
generation has not been deployed yet. The script text is `printf %q`-quoted and
the arrival step prints a sentinel the caller checks, so a push that never ran
fails instead of reporting success. It dials the fleet's sshd port from the
registry (`24212`), not 22, and needs root to hold an SSH identity for the peer
— check with `ssh -p 24212 root@yitaishi true` first.

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
