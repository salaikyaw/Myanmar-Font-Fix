#!/bin/bash
set -euo pipefail
case "$(hostname)" in
 sk-dell-1) expected_uuid=5f34835d-3487-404c-9e78-9ecb857ae822; expected_offset=101495808 ;;
 holymep) expected_uuid=0b9d12f1-23d5-4a05-9347-c29c2533a0f0; expected_offset=4093952 ;;
 *) echo 'Unexpected host'; exit 1 ;;
esac
test "$(findmnt -no UUID -T /swapfile)" = "$expected_uuid"
test "$(getconf PAGESIZE)" = 4096
test "$(stat -fc %S /swapfile)" = 4096
swapon --show=NAME --noheadings | grep -qx /swapfile
actual_offset=$(filefrag -v /swapfile | awk '$1 == "0:" {gsub(/\./,"",$4); print $4; exit}')
test "$actual_offset" = "$expected_offset"
backup=$(mktemp -d /var/backups/resume-swapfile-20260914-XXXXXX)
cp -a /etc/fstab "$backup/fstab"
cp -a /etc/default/grub "$backup/grub"
cp -a /etc/dracut.conf.d "$backup/dracut.conf.d"
cp -a /boot/grub/grub.cfg "$backup/grub.cfg"
printf 'Backup: %s\n' "$backup"
sed -i -E 's@^/swap\.img([[:space:]])@/swapfile\1@' /etc/fstab
sed -i -E "s/resume_offset=[0-9]+/resume_offset=$expected_offset/g" /etc/default/grub
printf 'add_dracutmodules+=" resume "\n' > /etc/dracut.conf.d/91-swapfile-resume.conf
findmnt --verify --tab-file /etc/fstab
update-initramfs -u -k all
update-grub
grub-script-check /boot/grub/grub.cfg
# Only change offset when the already configured device is the correct device.
# Writing /sys/power/resume can initiate resume and is deliberately avoided.
device=$(findmnt -nr -o MAJ:MIN -T /swapfile)
if [ "$(cat /sys/power/resume)" = "$device" ]; then
 printf '%s' "$expected_offset" > /sys/power/resume_offset
else
 echo 'Runtime device differs; runtime left unchanged, reboot needed.'
fi
systemctl daemon-reload
echo 'CONFIGURATION_UPDATED_NO_HIBERNATE_TEST'
cat /sys/power/resume /sys/power/resume_offset
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
