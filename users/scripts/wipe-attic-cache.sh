#!/usr/bin/env bash
set -euo pipefail

# Safely wipe all cached store paths and chunks from Attic while preserving
# the cache configuration, signing keypair, and authentication tokens.

if [ "$(id -u)" -ne 0 ]; then
  echo "Must be run as root: su - && wipe-attic-cache" >&2
  exit 1
fi

echo "Stopping Attic services..."
systemctl stop attic-watch-store.service attic-closure-keeper.timer attic-closure-keeper.service atticd.service

echo "Truncating object, NAR, and chunk metadata in PostgreSQL..."
runuser -u postgres -- psql -d atticd -c "TRUNCATE TABLE object, nar, chunk, chunkref CASCADE;"

echo "Removing chunk files from Attic storage..."
if test -d /var/lib/private/atticd/storage; then
  find /var/lib/private/atticd/storage/ -mindepth 1 -delete
fi

echo "Starting Attic services..."
systemctl start atticd.service attic-watch-store.service attic-closure-keeper.timer

echo "Triggering closure keeper to re-seed current system closures..."
systemctl start attic-closure-keeper.service || true

echo "Attic cache successfully wiped."
