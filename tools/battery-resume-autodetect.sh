#!/bin/sh
set -eu
# After a normal boot the kernel may retain resume_offset but clear resume.
# Let systemd discover the active swap file instead of rejecting that pair.
# Preserve an explicitly selected resume device.
if [ "$(cat /sys/power/resume)" = '0:0' ]; then
    printf '0\n' > /sys/power/resume_offset
fi
