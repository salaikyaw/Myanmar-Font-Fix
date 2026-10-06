#!/bin/bash
set -euo pipefail
test "$(hostname)" = sk-dell-1
units=()
for u in mcp-gateway-{core,coding,collaboration,searx,automation}.service docker.socket docker.service containerd.service; do
 systemctl is-active --quiet "$u" && units+=("$u")
done
restore() { systemctl start --no-block "${units[@]}" >&2 || true; }
trap restore EXIT
systemctl stop "${units[@]}" >&2
sync
tar --acls --xattrs --numeric-owner --sparse --one-file-system \
 --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run \
 --exclude=./tmp --exclude=./mnt --exclude=./media --exclude=./swap.img \
 --exclude=./swapfile --exclude=./var/log --exclude=./var/cache \
 -C / -cpf - . boot/efi | zstd -T2 -1
