#!/bin/bash
set -euo pipefail
umask 077
test "$(hostname)" = holymep
mountpoint -q /mnt/sk-hp-data
test "$(findmnt -nr -o SOURCE -T /mnt/sk-hp-data)" = /dev/sda1
dest=$(mktemp -d /mnt/sk-hp-data/localserver-1-backup-20260914-XXXXXX)
keydir=$(mktemp -d "$HOME/.localserver-1-recovery-20260914-XXXXXX")
head -c 48 /dev/urandom | base64 > "$keydir/passphrase"
printf '%s\n' "$dest" > "$HOME/.localserver-1-backup-latest"
printf '%s\n' "$keydir" > "$HOME/.localserver-1-backup-key-location"
printf 'Archive destination: %s\nRecovery key directory: %s\n' "$dest" "$keydir"
if ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes localserver-1 \
 'sudo -n bash /tmp/export-dell-backup.sh' 2> "$keydir/source.log" | \
 gpg --batch --yes --pinentry-mode loopback --passphrase-file "$keydir/passphrase" \
 --symmetric --cipher-algo AES256 --compress-algo none --output "$dest/rootfs.tar.zst.gpg.partial"; then
 mv "$dest/rootfs.tar.zst.gpg.partial" "$dest/rootfs.tar.zst.gpg"
 gpg --batch --pinentry-mode loopback --passphrase-file "$keydir/passphrase" \
 --decrypt "$dest/rootfs.tar.zst.gpg" 2> "$keydir/verify.log" | zstd -d | tar -tf - > "$keydir/manifest"
 sha256sum "$dest/rootfs.tar.zst.gpg" > "$dest/SHA256SUMS"
 printf 'VERIFIED_ARCHIVE\n' > "$dest/STATUS"
 echo VERIFIED_ARCHIVE
else
 echo BACKUP_INCOMPLETE >&2
 exit 1
fi
