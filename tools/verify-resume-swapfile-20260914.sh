#!/bin/bash
set -euo pipefail
offset=$(filefrag -v /swapfile | awk '$1 == "0:" {gsub(/\./,"",$4); print $4; exit}')
device=$(findmnt -nr -o MAJ:MIN -T /swapfile)
test "$(getconf PAGESIZE)" = 4096
test "$(stat -fc %S /swapfile)" = 4096
test "$(cat /sys/power/resume)" = "$device"
swapon --show=NAME --noheadings | grep -qx /swapfile
grep -q "resume_offset=$offset" /boot/grub/grub.cfg
printf '%s' "$offset" > /sys/power/resume_offset
test "$(cat /sys/power/resume_offset)" = "$offset"
echo "RUNTIME_AND_BOOT_OFFSET_MATCH=$offset DEVICE=$device"
grep '^/swap' /etc/fstab
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
lsinitrd -m /boot/initrd.img-$(uname -r) | grep resume
systemctl is-active battery-monitor
