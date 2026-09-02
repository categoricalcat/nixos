# CI And Binary Cache

This page walks you through the first-time setup of the self-hosted CI and binary cache
pipeline on a fresh NixOS server. By the end you will have:

- A Forgejo mirror synced from a GitHub repository
- Forgejo Actions building every `nixosConfigurations` on push
- An Attic binary cache storing build results
- A GitHub Actions trigger that connects GitHub pushes → Forgejo

**Prerequisites:**

- A GitHub repository with your NixOS flake
- A server (`yifuwuqi` in this repo's convention) running NixOS
- DNS pointing `git.<domain>`, `ci.<domain>`, and `cache.<domain>` at that server
- SOPS configured with a valid age key for `secrets/secrets.yaml`

## Configuration Sources

Every service in this pipeline has a single Nix module you edit. When the instructions below
say "update the address" or "change the public key", here is where each value lives:

| If you need to change…           | Edit this file                                                                |
| -------------------------------- | ----------------------------------------------------------------------------- |
| Domains, ports, Attic cache name | `modules/addresses.nix` (under `hosts.yifuwuqi.services`)                     |
| Forgejo configuration            | `modules/services/forgejo.nix`                                                |
| Forgejo Actions runner           | `modules/services/forgejo-runner.nix`                                         |
| Attic server                     | `modules/services/attic/server.nix`                                           |
| Attic watch-store push           | `modules/services/attic/watch-store.nix`                                      |
| Attic closure keeper             | `modules/services/attic/closure-keeper.nix`                                   |
| Reverse proxy (nginx)            | `modules/services/nginx-proxy.nix`                                            |
| Cache substituter + public key   | `modules/services/attic/client.nix` (imported via `modules/nix-settings.nix`) |

After deployment the endpoints resolve as:

| Endpoint             | Service        |
| -------------------- | -------------- |
| `git.fufu.land`      | Forgejo mirror |
| `cache.fufu.land/yi` | Attic cache    |

## Secret Inventory

SOPS secrets in `secrets/secrets.yaml`:

| Secret                        | Purpose                                  | How to obtain                                                        |
| ----------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `tokens/github-runner-nixos`  | Registers the self-hosted GitHub runner  | GitHub Repo Settings -> Actions -> Runners -> New self-hosted runner |
| `tokens/attic-server-jwt-env` | Attic server JWT signing secret env file | See [Generate SOPS Secrets](#generate-sops-secrets)                  |
| `tokens/attic-push-token`     | Token used by `attic-watch-store`        | See [Attic Bootstrap](#attic-bootstrap)                              |
| `tokens/forgejo-runner`       | Forgejo runner registration token        | Forgejo Admin -> Actions -> Runners                                  |

GitHub Actions repository secrets:

| Secret          | Purpose                                                | How to obtain                         |
| --------------- | ------------------------------------------------------ | ------------------------------------- |
| `FORGEJO_TOKEN` | Lets the trigger workflow sync/read the Forgejo mirror | See [Trigger Tokens](#trigger-tokens) |

Forgejo repository secrets:

| Secret        | Purpose                         | How to obtain                          |
| ------------- | ------------------------------- | -------------------------------------- |
| `attic_token` | Push token for Attic cache `yi` | Same as SOPS `tokens/attic-push-token` |

## Generate SOPS Secrets

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
```

## GitHub Runner Token

Create the runner registration token in GitHub:

1. Open the GitHub repository.
1. Go to Settings -> Actions -> Runners.
1. Select New self-hosted runner.
1. Copy the registration token.
1. Store it in SOPS as `tokens/github-runner-nixos`.

This is only the runner registration token. It is not the same as the GitHub
Actions repository secrets used by `trigger.yml`.

## First Deploy

Deploy `yifuwuqi` and `yirukou` after SOPS contains at least:

- `tokens/github-runner-nixos`
- `tokens/attic-server-jwt-env`
- `tokens/forgejo-runner`

Expected state after the first switch:

- Forgejo starts.
- Attic starts.
- The GitHub runner starts.
- Forgejo Actions may not be usable until the runner is registered.

## Forgejo Bootstrap

Open `git.fufu.land`.

1. Create the first admin user.
1. Create a read-only pull mirror from `https://github.com/categoricalcat/nixos`.
1. Redeploy `yifuwuqi`.

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
attic login yi http://127.0.0.1:24203 "$admin_token"
attic cache create yi --public --priority 38
attic cache info yi
push_token=$(sudo atticd-atticadm make-token --sub 'yi' --validity '10 years' --push 'yi' | tr -d '\r')
```

Then:

1. Put `push_token` in SOPS as `tokens/attic-push-token`.
1. Copy the public key from `attic cache info yi`.
1. Replace the placeholder key in `modules/services/attic/client.nix`.
1. Redeploy every host that should pull from `cache.fufu.land/yi`.

## Trigger Tokens

Create a Forgejo access token from the Forgejo user settings. It needs repository
API access to force mirror sync and read the mirrored branch. Add it to GitHub
Actions repository secrets as `FORGEJO_TOKEN`.

## Verification

Check services on `yifuwuqi`:

```bash
systemctl status forgejo gitea-actions-runner-yifuwuqi atticd attic-watch-store attic-closure-keeper.timer github-runner-nixos
```

Check the cache endpoint from a mesh host:

```bash
curl -I https://cache.fufu.land/yi/nix-cache-info
```

Push test:

1. Push to `develop`.
1. GitHub Actions trigger passes.
1. Forgejo mirror branch reaches the same commit SHA.
1. Forgejo Actions builds all hosts.
1. `attic cache info yi` shows objects.

## Forking This Setup

If you are adapting this repo for your own domains and secrets, replace every occurrence of:

| What                 | Default                | Replace with                                     |
| -------------------- | ---------------------- | ------------------------------------------------ |
| Domain               | `fufu.land`            | your domain                                      |
| Attic cache name     | `yi`                   | your cache name                                  |
| GitHub repo          | `categoricalcat/nixos` | your repo                                        |
| Attic JWT key        | (generate)             | `openssl genrsa -traditional 4096 \| base64 -w0` |
| Forgejo runner token | (fetch from UI)        | Forgejo Admin -> Actions -> Runners              |
| GitHub runner token  | (fetch from UI)        | Settings → Actions → Runners                     |

Search in these files for `fufu.land`, `categoricalcat`, and `yi`:

```bash
grep -rn 'fufu\.land\|categoricalcat' modules/ docs/ .github/ ci/
```

## Troubleshooting

- Attic config check fails: ensure `services.atticd.settings.chunking` exists in
  `modules/services/attic/server.nix`.
- GitHub trigger cannot reach Forgejo: the runner must be on
  `yifuwuqi`. The variables `FORGEJO_INTERNAL_URL`, and `GITHUB_REPO` are injected by running `setup-ci-env` in the workflow.
  This script is generated by `modules/services/github-runner.nix` and adds
  the correct values from the address registry to `$GITHUB_ENV`.
- Cache pulls fail: the public key in `modules/services/attic/client.nix` may still be
  the placeholder, or the client host may not have been redeployed.
