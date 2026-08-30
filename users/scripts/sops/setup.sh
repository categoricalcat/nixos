#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "sudoing..."
  exec sudo "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modular functions
# shellcheck source=users/scripts/sops/ensure-host-key.sh
source "$SCRIPT_DIR/ensure-host-key.sh"
# shellcheck source=users/scripts/sops/ensure-user-key.sh
source "$SCRIPT_DIR/ensure-user-key.sh"
# shellcheck source=users/scripts/sops/ensure-ci-key.sh
source "$SCRIPT_DIR/ensure-ci-key.sh"
# shellcheck source=users/scripts/sops/derive-age-key.sh
source "$SCRIPT_DIR/derive-age-key.sh"
# shellcheck source=users/scripts/sops/ssh-pub-to-age.sh
source "$SCRIPT_DIR/ssh-pub-to-age.sh"
# shellcheck source=users/scripts/sops/sync-secrets.sh
source "$SCRIPT_DIR/sync-secrets.sh"

ROTATE=false
TARGET_HOST=""

for arg in "$@"; do
  case "$arg" in
  --rotate)
    ROTATE=true
    ;;
  -*)
    echo "Unknown option: $arg" >&2
    exit 1
    ;;
  *)
    if [ "$TARGET_HOST" = "" ]; then
      TARGET_HOST="$arg"
    else
      echo "Unexpected extra positional argument: $arg" >&2
      exit 1
    fi
    ;;
  esac
done

HOSTNAME=${TARGET_HOST:-${HOST:-$(hostname)}}

if [ "$HOSTNAME" = "" ]; then
  echo "Usage: $0 [hostname] [--rotate]" >&2
  exit 1
fi

USER_HOME="/home/yi"
HOST_KEY="/persist/keys/ssh/ssh_host_ed25519_key"
MESH_KEY="$USER_HOME/.ssh/id_ed25519"
GIT_KEY="$USER_HOME/.ssh/id_git_ed25519"
AI_KEY="$USER_HOME/.ssh/id_ai_ed25519"

echo "=== setup for $HOSTNAME ==="

ensure_host_key "$HOST_KEY" "$HOSTNAME"

ensure_user_key yi yi "$MESH_KEY" "yi@$HOSTNAME"
ensure_user_key yi yi "$GIT_KEY" "yi@$HOSTNAME-git"
ensure_user_key yi yi "$AI_KEY" "ai@$HOSTNAME"

chown yi:yi "$USER_HOME/.ssh"
chmod 0700 "$USER_HOME/.ssh"

echo "-> generate sops age identity for yi"
derive_age_key "$MESH_KEY" "$USER_HOME/.config/sops/age/keys.txt" "yi:yi"

echo "-> generate sops age identity for root"
derive_age_key "$HOST_KEY" "/root/.config/sops/age/keys.txt" "root:root"

HOST_PUB=$(cat "$HOST_KEY.pub")
MESH_PUB=$(cat "$MESH_KEY.pub")
AI_PUB=$(cat "$AI_KEY.pub")
HOST_AGE=$(ssh_pub_to_age "$HOST_PUB")
MESH_AGE=$(ssh_pub_to_age "$MESH_PUB")

NEEDS_INSTRUCTIONS=false
if ! grep -Fq "$HOST_PUB" secrets/keys.nix 2>/dev/null; then
  NEEDS_INSTRUCTIONS=true
fi
if ! grep -Fq "$MESH_PUB" secrets/keys.nix 2>/dev/null; then
  NEEDS_INSTRUCTIONS=true
fi
if ! grep -Fq "$AI_PUB" secrets/keys.nix 2>/dev/null; then
  NEEDS_INSTRUCTIONS=true
fi

if [ "$NEEDS_INSTRUCTIONS" = "true" ]; then
  echo "-> Converting public keys to age recipients..."

  echo ""
  echo "=========================================="
  echo "    Add to secrets/keys.nix (hosts)       "
  echo "=========================================="
  printf '    %s = {\n      sshPublicKey = "%s";\n      ageRecipient = "%s";\n    };\n' "$HOSTNAME" "$HOST_PUB" "$HOST_AGE"

  echo ""
  echo "=========================================="
  echo "   Add to secrets/keys.nix (users.yi)     "
  echo "=========================================="
  printf '      %s = {\n        sshPublicKey = "%s";\n        ageRecipient = "%s";\n      };\n' "$HOSTNAME" "$MESH_PUB" "$MESH_AGE"

  echo ""
  echo "=========================================="
  echo "   Add to secrets/keys.nix (users.ai)     "
  echo "=========================================="
  printf '      %s = {\n        sshPublicKey = "%s";\n      };\n' "$HOSTNAME" "$AI_PUB"
fi

ensure_ci_key "$HOSTNAME" "$ROTATE"

echo ""
echo "=========================================="
echo "                  keys                    "
echo "=========================================="
GIT_PUB=$(cat "$GIT_KEY.pub")
echo "-> host age:    $HOST_AGE"
echo "-> mesh age:    $MESH_AGE"
echo "-> host pkey:   $HOST_PUB"
echo "-> mesh pkey:   $MESH_PUB"
echo "-> git pkey:    $GIT_PUB"
echo "-> ai pkey:     $AI_PUB"
if [ "$HOSTNAME" = "yifuwuqi" ]; then
  if [ -f "/run/ci-deploy-key/keys/deploy_ed25519.pub" ]; then
    CI_PUB=$(cat "/run/ci-deploy-key/keys/deploy_ed25519.pub")
  else
    CI_PUB=$(grep -oE 'deployPublicKey\s*=\s*"[^"]+' secrets/keys.nix 2>/dev/null | sed 's/.*"//' || true)
  fi
  if [ "$CI_PUB" != "" ]; then
    echo "-> ci pkey:     $CI_PUB"
  fi
fi
echo ""

sync_secrets
