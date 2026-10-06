#!/bin/sh
# KOReader launcher for Onion OS (Miyoo Mini V4)
# Installed at /mnt/SDCARD/App/KOReader/
# v5: run reader.lua directly (./luajit) with our own restart loop.
# koreader.sh's shebang/realpath chain segfaults on this box; direct exec works.

LOG=/mnt/SDCARD/App/KOReader/launch.log

# ---- [1] environment capture (system env, before we touch anything) ----
{
    echo "===== launch $(date) ====="
    echo "--- system LD_LIBRARY_PATH ---"
    echo "$LD_LIBRARY_PATH"
    echo "--- uname ---"
    uname -a
    echo "--- memory ---"
    free -m 2>&1
    echo "--- framebuffer ---"
    cat /sys/class/graphics/fb0/virtual_size 2>&1
    cat /sys/class/graphics/fb0/bits_per_pixel 2>&1
    echo "--- input devices ---"
    ls -l /dev/input/ 2>&1
} > "$LOG" 2>&1

# ---- [2] app environment ----
export HOME=/mnt/SDCARD
export KOREADER_DIR=/mnt/SDCARD/App/KOReader/koreader
export PATH="/mnt/SDCARD/App/KOReader/koreader:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/App/KOReader/koreader/libs:$LD_LIBRARY_PATH"
export LC_ALL="C"

cd "$KOREADER_DIR" || {
    echo "cd FAILED: $KOREADER_DIR not accessible" >> "$LOG" 2>&1
    sync
    exit 1
}

# ---- [3] run KOReader with the standard 85-restart loop ----
echo "--- koreader start ---" >> "$LOG" 2>&1
RETURN_VALUE=85
while [ "$RETURN_VALUE" -eq 85 ]; do
    ./luajit ./reader.lua "$@" >> "$LOG" 2>&1
    RETURN_VALUE=$?
    set --
done
echo "--- koreader exit: $RETURN_VALUE ---" >> "$LOG" 2>&1
sync
exit "$RETURN_VALUE"
