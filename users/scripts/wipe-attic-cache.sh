#!/usr/bin/env bash
set -e

# Run this as your NORMAL user (do not use sudo bash!) 
# The client config "yi" only exists for your user.
ATTIC_CLI="nix run github:zhaofengli/attic#attic --"

$ATTIC_CLI cache configure yi --retention-period '1s'
sleep 4

# Extract the absolute path for atticd from systemctl (since it's not in the PATH)
ATTICD_BIN=$(systemctl show atticd.service -P ExecStart | grep -o 'path=[^ ;]*' | cut -d= -f2)
ATTICD_CONF=$(systemctl show atticd.service -P ExecStart | grep -o '\-f [^ ]*' | cut -d' ' -f2)

echo "Temporarily stopping atticd to safely release database locks and namespaces..."
sudo systemctl stop atticd.service

# Now we can safely emulate the atticd environment without conflicts
sudo systemd-run --pty --wait \
  -p User=atticd \
  -p StateDirectory=atticd \
  -p DynamicUser=yes \
  -p EnvironmentFile=/run/secrets/tokens/attic-server-jwt-env \
  $ATTICD_BIN --mode garbage-collector-once --config $ATTICD_CONF

echo "Restarting atticd..."
sudo systemctl start atticd.service

$ATTIC_CLI cache configure yi --retention-period '15d'
