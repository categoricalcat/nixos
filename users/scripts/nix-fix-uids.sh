nix-fix-uids() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo -s nix-fix-uids"
    return 1
  fi

  local entries=(
    "yi:1000:1000:/home/yi"
    "workd:1001:1001:/home/workd"
    "none:1002:1002:/home/none"
  )

  for entry in "${entries[@]}"; do
    IFS=: read -r name target_uid target_gid home <<< "$entry"
    if [ -d "$home" ]; then
      current_uid=$(stat -c "%u" "$home")
      if [ "$current_uid" != "$target_uid" ]; then
        echo "Fixing $home: UID $current_uid -> $target_uid"
        chown -R "$target_uid:$target_gid" "$home"
      else
        echo "$home: already UID $target_uid, skipping"
      fi
    fi
  done

  if [ -d /srv/nfs/share ]; then
    current_uid=$(stat -c "%u" /srv/nfs/share)
    if [ "$current_uid" != "1000" ]; then
      echo "Fixing /srv/nfs/share: UID $current_uid -> 1000"
      chown -R 1000:1000 /srv/nfs/share
    else
      echo "/srv/nfs/share: already UID 1000, skipping"
    fi
  fi
}
