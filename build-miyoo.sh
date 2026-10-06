#!/usr/bin/env bash
# =============================================================================
# Build KOReader for Miyoo Mini (Onion OS App)
#
# Runs INSIDE the koreader/koappimage armhf container (see the workflow):
#   * applies the Miyoo patches to the KOReader source
#   * builds the `linux` target natively on arm/v7
#   * assembles an Onion OS app (Apps/KOReader/) and zips it
#
# Environment (set by the workflow):
#   KOREADER_SRC   - path to the KOReader source tree (default: /src)
#   OUT_DIR        - output directory for the zip (default: /dist)
#   PARALLEL_JOBS  - make parallelism (default: 4)
# =============================================================================
set -euo pipefail

PORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOREADER_DIR="${KOREADER_SRC:-/src}"
OUT_DIR="${OUT_DIR:-/dist}"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"

echo "PORT_DIR=${PORT_DIR}"
echo "KOREADER_DIR=${KOREADER_DIR}"

# --- [1/4] Apply patches -----------------------------------------------------
echo "==> [1/4] Applying Miyoo patches"

cd "${KOREADER_DIR}"

python3 - <<'PY'
import io

# 01: build libkoreader-input even for USE_SDL (linux) targets
p = "base/thirdparty/cmake_modules/koreader_targets.cmake"
s = io.open(p, encoding="utf-8").read()
old = "if(ANDROID OR POCKETBOOK OR USE_SDL)"
new = "if(ANDROID OR POCKETBOOK)"
assert old in s, "[patch01] pattern not found in koreader_targets.cmake"
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("  [01] koreader-input enabled for USE_SDL builds")

# 02: device probe: add the miyoo branch
p = "frontend/device.lua"
s = io.open(p, encoding="utf-8").read()
old = '''        elseif platform:sub(1, #"remarkable") == "remarkable" then
            return require("device/remarkable/device")
        end'''
new = '''        elseif platform:sub(1, #"remarkable") == "remarkable" then
            return require("device/remarkable/device")
        elseif platform:sub(1, #"miyoo") == "miyoo" then
            return require("device/miyoo/device")
        end'''
assert old in s, "[patch02] pattern not found in device.lua"
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("  [02] miyoo branch added to device.lua")
PY

# 03: install the Miyoo device backend into the source tree
mkdir -p "${KOREADER_DIR}/frontend/device/miyoo"
cp -v "${PORT_DIR}"/miyoo/*.lua "${KOREADER_DIR}/frontend/device/miyoo/"

# --- [2/4] Build -------------------------------------------------------------
echo "==> [2/4] Building KOReader (TARGET=linux, armhf)"
cd "${KOREADER_DIR}"
make TARGET=linux PARALLEL_JOBS="${PARALLEL_JOBS}" all

# --- [3/4] Locate artifacts & fix launcher -----------------------------------
echo "==> [3/4] Assembling Onion app"

APPDIR="$(ls -d koreader-linux-*/koreader 2>/dev/null | head -1)"
if [ -z "${APPDIR}" ]; then
    echo "ERROR: build artifact not found (expected koreader-linux-*/koreader)"
    exit 1
fi
echo "  artifact: ${APPDIR}"

# git-rev must carry the _miyoo platform tag so frontend/device.lua probes it
sed -i 's/_linux$/_miyoo/' "${APPDIR}/git-rev" || true
# A --depth 1 clone has no tags, so VERSION was empty and git-rev would be just
# "_miyoo"; provide a sane fallback so version parsing never breaks.
if ! grep -qE '^v[0-9][^_]*_miyoo' "${APPDIR}/git-rev"; then
    echo "v0.0.0_miyoo" > "${APPDIR}/git-rev"
fi
echo "  git-rev: $(cat "${APPDIR}/git-rev")"

# koreader.sh: remove KO_MULTIUSER (would force the Desktop/SDL device probe)
sed -i '/export KO_MULTIUSER=1/d' "${APPDIR}/koreader.sh"
# Use a locale that exists on minimal embedded systems
sed -i 's/LC_ALL="en_US.UTF-8"/LC_ALL="C.UTF-8"/' "${APPDIR}/koreader.sh" || true
chmod +x "${APPDIR}/koreader.sh"

# --- [4/4] Package as Onion App ----------------------------------------------
echo "==> [4/4] Packaging Onion app (Apps/KOReader/)"

STAGE="/tmp/onion/Apps/KOReader"
rm -rf /tmp/onion
mkdir -p "${STAGE}"

cp -v "${PORT_DIR}/app/config.json" "${STAGE}/config.json"
cp -v "${PORT_DIR}/app/launch.sh"    "${STAGE}/launch.sh"
cp -v "${PORT_DIR}/app/icon.png"     "${STAGE}/icon.png"
chmod +x "${STAGE}/launch.sh"
# -L: dereference symlinks (the build output is mostly a symlink farm pointing
# at base/build artifacts; we must copy real content, not links)
cp -aLv "${APPDIR}" "${STAGE}/koreader"

mkdir -p "${OUT_DIR}"
python3 - <<'PY'
import os, zipfile

stage = "/tmp/onion"
out = os.environ.get("OUT_DIR", "/dist") + "/koreader-miyoo-onion.zip"
count = 0
skipped = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(stage):
        for f in sorted(files):
            if f.endswith(".dbg"):
                # skip debug-symbol files (luajit.dbg / sdcv.dbg): huge, unused
                continue
            p = os.path.join(root, f)
            arc = os.path.relpath(p, "/tmp")
            # The build creates some files as symlinks (Makefile SYMLINK mechanism).
            # Follow the link and store the real content; skip broken links.
            if os.path.islink(p):
                real = os.path.realpath(p)
                if not os.path.exists(real):
                    print("  WARN: skip broken symlink", arc, "->", os.readlink(p))
                    skipped += 1
                    continue
                p = real
            try:
                with open(p, "rb") as fh:
                    data = fh.read()
            except OSError as e:
                print("  WARN: skip unreadable file", arc, ":", e)
                skipped += 1
                continue
            zi = zipfile.ZipInfo(arc)
            mode = os.stat(p).st_mode
            # Preserve unix permissions (executable bits for launch.sh / binaries)
            zi.external_attr = (mode & 0xFFFF) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(zi, data)
            count += 1
print(f"  {out}: {count} files packed, {skipped} skipped")
PY

ls -la "${OUT_DIR}/"
echo "==> BUILD COMPLETE"
