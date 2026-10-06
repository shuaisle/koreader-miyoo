#!/bin/sh
# KOReader launcher for Onion OS (Miyoo Mini V4)
# Installed at /mnt/SDCARD/App/KOReader/
# v3: capture environment BEFORE touching LD_LIBRARY_PATH; then APPEND (not
# override) so system binaries (date/sh/ls need libmi_common.so) keep working.

LOG=/mnt/SDCARD/App/KOReader/launch.log

# ---- [1] environment capture with the ORIGINAL system environment ----
{
    echo "===== launch $(date) ====="
    echo "--- system LD_LIBRARY_PATH ---"
    echo "$LD_LIBRARY_PATH"
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
    echo "--- glibc ---"
    for ld in /lib/ld-linux*.so.* /usr/lib/ld-linux*.so.*; do
        [ -e "$ld" ] && "$ld" --version 2>&1
    done
    echo "--- libmi_common location ---"
    find /lib /usr/lib /customer /mi -name 'libmi_common.so*' 2>/dev/null | head -5
} > "$LOG" 2>&1

# ---- [2] app environment: APPEND so system libs remain resolvable ----
export HOME=/mnt/SDCARD
export PATH="/mnt/SDCARD/App/KOReader/koreader:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/App/KOReader/koreader/libs:$LD_LIBRARY_PATH"

cd /mnt/SDCARD/App/KOReader/koreader || {
    echo "cd FAILED: koreader dir not accessible" >> "$LOG" 2>&1
    sync
    exit 1
}

echo "--- koreader start ---" >> "$LOG" 2>&1
./koreader.sh "$@" >> "$LOG" 2>&1
echo "--- koreader exit: $? ---" >> "$LOG" 2>&1
sync
