#!/bin/sh
# KOReader launcher for Onion OS (Miyoo Mini V4)
# Installed at /mnt/SDCARD/Apps/KOReader/

export HOME=/mnt/SDCARD
export PATH="/mnt/SDCARD/Apps/KOReader/koreader:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/Apps/KOReader/koreader/libs"

cd /mnt/SDCARD/Apps/KOReader/koreader || exit 1
./koreader.sh

sync
