#!/bin/bash
set -euo pipefail
# Configure only. Never suspend, hibernate, or reboot during repair.
backup=/var/backups/battery-hibernate-20260908
mkdir -p "$backup"
cp -an /etc/systemd/sleep.conf.d/99-always-on.conf "$backup/"
cp -an /etc/initramfs-tools/conf.d/resume "$backup/"
uuid=$(findmnt -n -o UUID -T /swap.img)
offset=$(filefrag -v /swap.img | awk '$1=="0:" {gsub(/\./,"",$4); print $4; exit}')
[[ "$uuid" =~ ^[a-f0-9-]+$ && "$offset" =~ ^[0-9]+$ ]]
printf 'RESUME=UUID=%s\n' "$uuid" > /etc/initramfs-tools/conf.d/resume
printf '[Sleep]\nAllowSuspend=no\nAllowHibernation=yes\nAllowSuspendThenHibernate=no\nAllowHybridSleep=no\n' > /etc/systemd/sleep.conf.d/99-always-on.conf
systemctl unmask sleep.target hibernate.target
if [ "$(cat /sys/power/resume)" = '0:0' ]; then
    printf '0\n' > /sys/power/resume_offset
fi
update-initramfs -u > "$backup/initramfs.log" 2>&1
update-grub > "$backup/grub.log" 2>&1
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
printf 'CONFIGURED_ONLY_NO_POWER_TRANSITION\n'
