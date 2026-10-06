#!/bin/bash
set -euo pipefail
test "$(hostname)" = sk-dell-1
test -s /home/sk-dell-1/.docker/mcp/catalogs/docker-official-20260914.yaml
backup=$(mktemp -d /var/backups/mcp-catalog-20260914-XXXXXX)
for name in data research cloud system; do
 unit=mcp-gateway-$name.service
 start=$(systemctl cat "$unit" | grep '^ExecStart=/usr/bin/docker mcp gateway run ' | head -1)
 test -n "$start"
 systemctl cat "$unit" > "$backup/$unit"
 dir=/etc/systemd/system/$unit.d
 mkdir -p "$dir"
 test ! -e "$dir/90-local-catalog.conf"
 printf '[Service]\nExecStart=\n%s --catalog docker-official-20260914.yaml\n' "$start" > "$dir/90-local-catalog.conf"
done
systemctl daemon-reload
systemctl start --no-block mcp-gateway-data mcp-gateway-research mcp-gateway-cloud mcp-gateway-system mcp-gateway-trading
echo "CATALOG_OVERRIDE_BACKUP=$backup"
