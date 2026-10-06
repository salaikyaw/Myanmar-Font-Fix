#!/bin/bash
set -euo pipefail
test "$(hostname)" = sk-dell-1
backup=$(mktemp -d /var/backups/mcp-egress-20260914-XXXXXX)
for name in core coding automation collaboration data research cloud system trading searx; do
 unit=mcp-gateway-$name.service
 systemctl cat "$unit" > "$backup/$unit"
 dir=/etc/systemd/system/$unit.d
 mkdir -p "$dir"
 test ! -e "$dir/91-mcp-egress.conf"
 printf '[Unit]\nWants=mcp-egress-skhp.service\nAfter=mcp-egress-skhp.service\n[Service]\nEnvironment="HTTPS_PROXY=socks5://127.0.0.1:1082" "HTTP_PROXY=socks5://127.0.0.1:1082" "ALL_PROXY=socks5://127.0.0.1:1082" "NO_PROXY=localhost,127.0.0.1,::1,192.168.1.0/24,172.17.0.0/16,100.64.0.0/10"\n' > "$dir/91-mcp-egress.conf"
done
install -m 644 /tmp/mcp-egress-skhp.service /etc/systemd/system/mcp-egress-skhp.service
systemctl stop mcp-egress-probe
systemctl daemon-reload
systemctl enable --now mcp-egress-skhp
systemctl restart --no-block mcp-gateway-core mcp-gateway-coding mcp-gateway-automation mcp-gateway-collaboration mcp-gateway-data mcp-gateway-research mcp-gateway-cloud mcp-gateway-system mcp-gateway-trading mcp-gateway-searx
echo "BACKUP=$backup"
