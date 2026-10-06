#!/bin/sh
# KOReader launcher for Onion OS (Miyoo Mini V4)
# Installed at /mnt/SDCARD/Apps/KOReader/

export HOME=/mnt/SDCARD
export PATH="/mnt/SDCARD/Apps/KOReader/koreader:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/Apps/KOReader/koreader/libs"

cd /mnt/SDCARD/Apps/KOReader/koreader || exit 1

# No-network device forensics: dump the environment + all runtime output to
# launch.log on the SD card (readable on any PC after unplugging the card).
# This replaces SSH for collecting glibc / fb0 / input-device info.
{
    echo "===== $(date) ====="
    echo "--- uname ---"
    uname -a
    echo "--- cpu ---"
    head -5 /proc/cpuinfo 2>&1
    echo "--- memory ---"
    free -m 2>&1
    echo "--- framebuffer ---"
    cat /sys/class/graphics/fb0/virtual_size 2>&1
    cat /sys/class/graphics/fb0/bits_per_pixel 2>&1
    echo "--- input devices ---"
    ls -l /dev/input/ 2>&1
    cat /proc/bus/input/devices 2>&1
    echo "--- system libs (glibc) ---"
    ls /lib/ld-linux* 2>&1
    for ld in /lib/ld-linux*.so.*; do
        [ -e "$ld" ] && "$ld" --version 2>&1
    done
    ldd --version 2>&1 | head -2
    echo "--- koreader start ---"
    ./koreader.sh "$@"
    echo "--- koreader exit: $? ---"
} > /mnt/SDCARD/Apps/KOReader/launch.log 2>&1

sync
