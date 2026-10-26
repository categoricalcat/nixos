# Forgejo Primary & GitHub Push Mirror Runbook

Imperative runbook to transition Forgejo (`git.fufu.land`) from a read-only pull mirror to the primary writable forge, continuously mirroring to GitHub via an SSH Deploy Key.

No NixOS configuration changes are required.

______________________________________________________________________

## 1. Convert Forgejo Repo to Regular (Primary)

1. Open `https://git.fufu.land/yi/nixos/settings`.
1. Under **Mirror Settings**, click **Convert to regular repository**.
1. Confirm the conversion. The repository is now writable.

______________________________________________________________________

## 2. Configure SSH Push Mirror (Forgejo → GitHub)

### In Forgejo:

1. Navigate to `https://git.fufu.land/yi/nixos/settings/repository`.
1. Scroll to **Push Mirrors** and click **Add Push Mirror**.
1. Fill in:
   - **Target URL**: `git@github.com:categoricalcat/nixos.git`
   - **Sync when commits are pushed**: Checked (enables immediate sync)
1. Click **Add Push Mirror**.
1. Copy the generated **Public Key** displayed beside the new mirror.

### In GitHub:

1. Navigate to `https://github.com/categoricalcat/nixos/settings/keys`.
1. Click **Add deploy key**:
   - **Title**: `Forgejo Push Mirror (yifuwuqi)`
   - **Key**: Paste the public key copied from Forgejo.
   - **Allow write access**: Checked (mandatory for push mirror).
1. Click **Add key**.

### Verify Sync:

Back in Forgejo (`Push Mirrors` section), click **Sync now** and verify the status indicator turns green.

______________________________________________________________________

## 3. Switch Local Workstation Remotes

Run on each active workstation (`yitaishi`, `yichuang`, etc.):

```bash
# Point origin to Forgejo (SSH on port 24212)
git remote set-url origin ssh://forgejo@git.fufu.land:24212/yi/nixos.git

# Optional: retain GitHub as a secondary remote
git remote add github git@github.com:categoricalcat/nixos.git

# Verify remote URLs
git remote -v

# Test push: triggers Forgejo Actions on yifuwuqi and auto-syncs to GitHub
git push origin develop
```
