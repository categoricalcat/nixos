# CI And Binary Cache

This page walks you through the first-time setup of the self-hosted CI and binary cache
pipeline on a fresh NixOS server. By the end you will have:

- A Forgejo mirror synced from a GitHub repository
- Woodpecker CI building every `nixosConfigurations` on push
- An Attic binary cache storing build results
- A GitHub Actions trigger that connects GitHub pushes → Forgejo → Woodpecker

**Prerequisites:**
- A GitHub repository with your NixOS flake
- A server (`yifuwuqi` in this repo's convention) running NixOS
- DNS pointing `git.<domain>`, `ci.<domain>`, and `cache.<domain>` at that server
- SOPS configured with a valid age key for `secrets/secrets.yaml`

## Configuration Sources

Every service in this pipeline has a single Nix module you edit. When the instructions below
say "update the address" or "change the public key", here is where each value lives:

| If you need to change… | Edit this file |
|---|---|
| Domains, ports, Attic cache name | `modules/addresses.nix` (under `hosts.yifuwuqi.services`) |
| Forgejo configuration | `modules/services/forgejo.nix` |
| Woodpecker server/agent | `modules/services/woodpecker.nix` |
| Attic server | `modules/services/atticd.nix` |
| Attic watch-store push | `modules/services/attic-watch-store.nix` |
| Reverse proxy (nginx) | `modules/services/nginx-proxy.nix` |
| Cache substituter + public key | `modules/nix-settings.nix` |

After deployment the endpoints resolve as:

| Endpoint | Service |
|---|---|
| `git.fufu.land` | Forgejo mirror |
| `ci.fufu.land` | Woodpecker |
| `cache.fufu.land/yi` | Attic cache |

## Secret Inventory

SOPS secrets in `secrets/secrets.yaml`:

| Secret | Purpose | How to obtain |
| --- | --- | --- |
| `tokens/github-runner-nixos` | Registers the self-hosted GitHub runner | GitHub Repo Settings -> Actions -> Runners -> New self-hosted runner |
| `tokens/attic-server-jwt-env` | Attic server JWT signing secret env file | See [Generate SOPS Secrets](#generate-sops-secrets) |
| `tokens/attic-push-token` | Token used by `attic-watch-store` | See [Attic Bootstrap](#attic-bootstrap) |
| `woodpecker/agent-secret` | Shared Woodpecker server/agent secret | `openssl rand -hex 32` |
| `woodpecker/forgejo-client` | Forgejo OAuth client id for Woodpecker | See [Forgejo Bootstrap](#forgejo-bootstrap) |
| `woodpecker/forgejo-secret` | Forgejo OAuth client secret for Woodpecker | See [Forgejo Bootstrap](#forgejo-bootstrap) |

GitHub Actions repository secrets:

| Secret | Purpose | How to obtain |
| --- | --- | --- |
| `FORGEJO_TOKEN` | Lets the trigger workflow sync/read the Forgejo mirror | See [Trigger Tokens](#trigger-tokens) |
| `WOODPECKER_TOKEN` | Lets the trigger workflow start a Woodpecker pipeline | See [Trigger Tokens](#trigger-tokens) |

Woodpecker repository secrets:

| Secret | Purpose | How to obtain |
| --- | --- | --- |
| `attic_token` | Push token for Attic cache `yi` | Same as SOPS `tokens/attic-push-token` |
| `github_status_token` | Token used by `ci/github-status.sh` to set GitHub commit status | GitHub PAT with commit status write permission |

## Generate SOPS Secrets

Generate the Woodpecker shared secret:

```bash
openssl rand -hex 32
```

Generate the Attic server JWT env value:

```bash
printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="%s"\n' \
  "$(openssl genrsa -traditional 4096 | base64 -w0)"
```

Edit the encrypted payload:

```bash
sops secrets/secrets.yaml
```

Store the generated values as:

```yaml
tokens:
    attic-server-jwt-env: |
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="..."
woodpecker:
    agent-secret: "..."
```

`woodpecker/forgejo-client` and `woodpecker/forgejo-secret` can start as
temporary placeholders. Replace them after creating the Forgejo OAuth app.

## GitHub Runner Token

Create the runner registration token in GitHub:

1. Open the GitHub repository.
2. Go to Settings -> Actions -> Runners.
3. Select New self-hosted runner.
4. Copy the registration token.
5. Store it in SOPS as `tokens/github-runner-nixos`.

This is only the runner registration token. It is not the same as the GitHub
Actions repository secrets used by `trigger.yml`.

## First Deploy

Deploy `yifuwuqi` and `yirukou` after SOPS contains at least:

- `tokens/github-runner-nixos`
- `tokens/attic-server-jwt-env`
- `woodpecker/agent-secret`
- placeholder `woodpecker/forgejo-client`
- placeholder `woodpecker/forgejo-secret`

Expected state after the first switch:

- Forgejo starts.
- Attic starts.
- The GitHub runner starts.
- Woodpecker may not be usable until the real Forgejo OAuth values are added.

## Forgejo Bootstrap

Open `git.fufu.land`.

1. Create the first admin user.
2. Create a read-only pull mirror from `https://github.com/categoricalcat/nixos`.
3. Create a Forgejo OAuth app for Woodpecker:
   - Redirect URL: `https://ci.fufu.land/authorize`
4. Put the OAuth client id and secret in SOPS:
   - `woodpecker/forgejo-client`
   - `woodpecker/forgejo-secret`
5. Redeploy `yifuwuqi`.

After the admin user exists, flip `service.DISABLE_REGISTRATION = true` in
`modules/services/forgejo.nix` in a later config change.

## Attic Bootstrap

Run on `yifuwuqi` after `atticd` is running.

> **Note:** `atticd-atticadm` runs as the `atticd` user via `systemd-run` and
> cannot `cd` into restricted directories. Run from `/tmp` to avoid permission
> errors. The `attic` CLI is not in system packages — use `nix shell` to get it.

```bash
cd /tmp
nix shell github:zhaofengli/attic#attic-client
admin_token=$(sudo atticd-atticadm make-token --sub 'admin' --validity '10 years' --pull '*' --push '*' --create-cache '*' --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*' | tr -d '\r')
attic login yi http://127.0.0.1:18203 "$admin_token"
attic cache create yi --public --priority 38
attic cache info yi
push_token=$(sudo atticd-atticadm make-token --sub 'yi' --validity '10 years' --push 'yi' | tr -d '\r')
```

Then:

1. Put `push_token` in SOPS as `tokens/attic-push-token`.
2. Copy the public key from `attic cache info yi`.
3. Replace the placeholder key in `modules/nix-settings.nix`.
4. Redeploy every host that should pull from `cache.fufu.land/yi`.

## Woodpecker Bootstrap

Open `ci.fufu.land`.

1. Log in via Forgejo OAuth.
2. Enable repository `categoricalcat/nixos`.
3. Add Woodpecker repository secrets:
   - `attic_token`: same value as SOPS `tokens/attic-push-token`
   - `github_status_token`: GitHub token allowed to write commit statuses

For `github_status_token`, use a fine-grained GitHub token for
`categoricalcat/nixos` with commit status write permission if available. A
classic token with `repo:status` is the fallback for status updates.

## Trigger Tokens

Create a Forgejo access token from the Forgejo user settings. It needs repository
API access to force mirror sync and read the mirrored branch. Add it to GitHub
Actions repository secrets as `FORGEJO_TOKEN`.

Create a Woodpecker user/API token after logging into Woodpecker. It needs access
to look up the repo and trigger a pipeline. Add it to GitHub Actions repository
secrets as `WOODPECKER_TOKEN`.

## Verification

Check services on `yifuwuqi`:

```bash
systemctl status forgejo woodpecker-server woodpecker-agent-local atticd attic-watch-store github-runner-nixos
```

Check the cache endpoint from a mesh host:

```bash
curl -I https://cache.fufu.land/yi/nix-cache-info
```

Push test:

1. Push to `develop`.
2. GitHub Actions `trigger woodpecker` passes.
3. Forgejo mirror branch reaches the same commit SHA.
4. Woodpecker builds all hosts.
5. `attic cache info yi` shows objects.
6. GitHub commit gets `ci/woodpecker` status.

## Forking This Setup

If you are adapting this repo for your own domains and secrets, replace every occurrence of:

| What | Default | Replace with |
|---|---|---|
| Domain | `fufu.land` | your domain |
| Attic cache name | `yi` | your cache name |
| GitHub repo | `categoricalcat/nixos` | your repo |
| Attic JWT key | (generate) | `openssl genrsa -traditional 4096 \| base64 -w0` |
| Woodpecker agent secret | (generate) | `openssl rand -hex 32` |
| GitHub runner token | (fetch from UI) | Settings → Actions → Runners |

Search in these files for `fufu.land`, `categoricalcat`, and `yi`:

```bash
grep -rn 'fufu\.land\|categoricalcat' modules/ docs/ .github/ ci/
```

## Troubleshooting

- Attic config check fails: ensure `services.atticd.settings.chunking` exists in
  `modules/services/atticd.nix`.
- GitHub trigger cannot reach Forgejo or Woodpecker: the runner must be on
  `yifuwuqi`, and `modules/services/github-runner.nix` must export
  `FORGEJO_INTERNAL_URL`, `WOODPECKER_INTERNAL_URL`, and `GITHUB_REPO` from
  the address registry.
- GitHub status is missing: check the Woodpecker `github_status_token` repo
  secret and the `GITHUB_REPO` environment passed to the Woodpecker agent.
- Cache pulls fail: the public key in `modules/nix-settings.nix` may still be
  the placeholder, or the client host may not have been redeployed.
