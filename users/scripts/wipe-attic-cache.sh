#!/usr/bin/env bash
set -euo pipefail

# Safely wipe all cached store paths and chunks from Attic while preserving
# the cache configuration, signing keypair, and authentication tokens.

echo "Stopping Attic services..."
sudo systemctl stop attic-watch-store.service attic-closure-keeper.timer attic-closure-keeper.service atticd.service

echo "Truncating object, NAR, and chunk metadata in PostgreSQL..."
sudo -u postgres psql -d atticd -c "TRUNCATE TABLE object, nar, chunk, chunkref CASCADE;"

echo "Removing chunk files from Attic storage..."
if sudo test -d /var/lib/private/atticd/storage; then
  sudo find /var/lib/private/atticd/storage/ -mindepth 1 -delete
fi

echo "Starting Attic services..."
sudo systemctl start atticd.service attic-watch-store.service attic-closure-keeper.timer

echo "Triggering closure keeper to re-seed current system closures..."
sudo systemctl start attic-closure-keeper.service || true

echo "Attic cache successfully wiped."
