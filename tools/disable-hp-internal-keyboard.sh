#!/bin/sh
# This faulty built-in keyboard must stay disabled after boot AND resume.
for dev in /sys/bus/serio/devices/*; do
    [ -r "$dev/description" ] || continue
    [ "$(cat "$dev/description")" = 'i8042 KBD port' ] || continue
    # Prevent serio from automatically attaching atkbd again after unbind.
    if [ -w "$dev/bind_mode" ]; then
        printf '%s' manual > "$dev/bind_mode" || exit 1
    fi
    [ -L "$dev/driver" ] || continue
    [ "$(basename "$(readlink "$dev/driver")")" = 'atkbd' ] || continue
    printf '%s\n' "$(basename "$dev")" > /sys/bus/serio/drivers/atkbd/unbind
done
