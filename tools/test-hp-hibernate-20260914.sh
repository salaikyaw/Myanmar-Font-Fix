#!/bin/bash
set -euo pipefail
test "$(hostname)" = holymep
if runuser -u sk-hp -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active --quiet dell-backup-20260914; then
 echo 'Refusing hibernate while backup is active'; exit 1
fi
test -f /mnt/sk-hp-data/localserver-1-backup-20260914-NxvZww/STATUS
grep -qx VERIFIED_ARCHIVE /mnt/sk-hp-data/localserver-1-backup-20260914-NxvZww/STATUS
test "$(cat /sys/power/resume_offset)" = 4093952
test "$(cat /sys/power/resume)" = '8:18'
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate | grep -q yes
out=$(mktemp -d /var/tmp/hp-hibernate-test-20260914-XXXXXX)
echo "$out"
cat /proc/sys/kernel/random/boot_id > "$out/boot-before"
systemctl list-units --type=service --state=running --no-legend --plain | awk '{print $1}' > "$out/services-before"
date --iso-8601=seconds > "$out/start"
/usr/local/sbin/disable-hp-internal-keyboard
rtcwake -m no -s 120
systemctl hibernate
cat /proc/sys/kernel/random/boot_id > "$out/boot-after"
date --iso-8601=seconds > "$out/end"
cmp "$out/boot-before" "$out/boot-after"
sleep 10
test "$(cat /sys/bus/serio/devices/serio0/bind_mode)" = manual
test ! -L /sys/bus/serio/devices/serio0/driver
systemctl is-active battery-monitor
echo SAME_BOOT_AND_KEYBOARD_PASS
