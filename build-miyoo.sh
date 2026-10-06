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
# 03: provide a default generateFakeEvent() so libkoreader-input links.
# input.c calls it unconditionally in the "fake_events" branch; every platform
# header (kindle/kobo/...) implements it, generic Linux/Miyoo gets a no-op that
# keeps the fake-event child alive without injecting any events.
p = "base/input/input.c"
s = io.open(p, encoding="utf-8").read()
old = '''#elif defined(CERVANTES)
#    include "input-cervantes.h"
#endif'''
new = '''#elif defined(CERVANTES)
#    include "input-cervantes.h"
#else
// Generic fallback (Miyoo Mini & other Linux targets): keep the fake-event
// child alive without injecting any events. The pipe stays open until this
// child is killed via its PDEATHSIG.
static void generateFakeEvent(int pipefd[2]) {
    (void)pipefd;
    for (;;) {
        pause();
    }
}
#endif'''
assert old in s, "[patch03] pattern not found in input.c"
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("  [03] generateFakeEvent fallback added to input.c")
PY

# 04: install the Miyoo device backend into the source tree
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
# "_miyoo"; provide a valid vYYYY.MM fallback (frontend/version.lua needs
# v(%d%d%d%d).(%d%d), "v0.0.0" does NOT match and crashes plugin loading).
if ! grep -qE '^v[0-9]{4}\.[0-9]{2}\.[0-9]+[^_]*_miyoo' "${APPDIR}/git-rev"; then
    echo "v2026.09.1_miyoo" > "${APPDIR}/git-rev"
fi
echo "  git-rev: $(cat "${APPDIR}/git-rev")"

# koreader.sh: remove KO_MULTIUSER (would force the Desktop/SDL device probe)
sed -i '/export KO_MULTIUSER=1/d' "${APPDIR}/koreader.sh"
# Use a locale that always exists: C.UTF-8 locale data is absent on Miyoo and
# makes the whole koreader.sh path segfault (direct luajit run without it is fine)
sed -i 's/export LC_ALL="en_US.UTF-8"/export LC_ALL="C"/' "${APPDIR}/koreader.sh" || true
chmod +x "${APPDIR}/koreader.sh"

# --- [4/4] Package as Onion App ----------------------------------------------
echo "==> [4/4] Packaging Onion app (App/KOReader/)"

STAGE="/tmp/App/KOReader"
rm -rf /tmp/App
mkdir -p "${STAGE}"

cp -v "${PORT_DIR}/app/config.json" "${STAGE}/config.json"
cp -v "${PORT_DIR}/app/launch.sh"    "${STAGE}/launch.sh"
cp -v "${PORT_DIR}/app/icon.png"     "${STAGE}/icon.png"
chmod +x "${STAGE}/launch.sh"
# -L: dereference symlinks (the build output is mostly a symlink farm pointing
# at base/build artifacts; we must copy real content, not links)
cp -aLv "${APPDIR}" "${STAGE}/koreader"

# Miyoo keymap fix: write the community-verified keymap into settings/ so it
# overrides the built-in table at startup (and is user-tweakable without a rebuild).
mkdir -p "${STAGE}/koreader/settings"
cp -v "${PORT_DIR}/app/event_map.lua" "${STAGE}/koreader/settings/event_map.lua"

# --- [3.5] Bundle glibc/libstdc++ for Miyoo + retarget dynamic linker -----------
# Miyoo's system glibc is too old (GLIBC_2.34 missing) and its libstdc++ lacks
# GLIBCXX_3.4.29 (liblunasvg/rapidjson are C++). Ship the build container's
# glibc 2.35 + libstdc++ (Ubuntu 22.04 armhf) inside koreader/libs and point
# every executable at our ld-linux so luajit stops loading /lib/libc.so.6.
echo "==> [3.5] Bundling glibc 2.35 and retargeting dynamic linker"

GLIBCDIR=/usr/lib/arm-linux-gnueabihf
if [ ! -d "${GLIBCDIR}" ]; then
    echo "  ERROR: ${GLIBCDIR} not found — cannot bundle glibc"
    exit 1
fi
for lib in ld-linux-armhf.so.3 libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 libgcc_s.so.1 libstdc++.so.6; do
    if [ -e "${GLIBCDIR}/${lib}" ]; then
        cp -L "${GLIBCDIR}/${lib}" "${STAGE}/koreader/libs/"
        echo "  + ${lib}"
    fi
done

# Retarget the ELF interpreter WITHOUT patchelf (not available in this image):
# append the new interpreter path to the end of the file and repoint PT_INTERP.
python3 - <<'PY'
import os, struct

def set_interp(path, new_interp):
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if data[:4] != b"\x7fELF":
        print(f"  WARN: {path} is not an ELF file")
        return
    e_phoff = struct.unpack_from("<I", data, 0x1c)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x2a)[0]
    e_phnum = struct.unpack_from("<H", data, 0x2c)[0]
    new_bytes = new_interp.encode() + b"\x00"
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type != 3:  # PT_INTERP
            continue
        p_vaddr = struct.unpack_from("<I", data, off + 8)[0]
        p_paddr = struct.unpack_from("<I", data, off + 12)[0]
        if len(data) % 8:
            data.extend(b"\x00" * (8 - len(data) % 8))
        new_off = len(data)
        data.extend(new_bytes)
        struct.pack_into("<IIII", data, off + 4, new_off, p_vaddr, p_paddr, len(new_bytes))
        with open(path, "wb") as f:
            f.write(data)
        with open(path, "rb") as f:  # verify
            _ = f.read()
        print(f"  {path}: interpreter -> {new_interp}")
        return
    print(f"  WARN: {path} has no PT_INTERP")

INTERP = "/mnt/SDCARD/App/KOReader/koreader/libs/ld-linux-armhf.so.3"
for name in ("luajit", "sdcv"):
    p = os.path.join("/tmp/App/KOReader/koreader", name)
    if os.path.exists(p):
        set_interp(p, INTERP)
    else:
        print(f"  (skip {name}: not present)")
PY

mkdir -p "${OUT_DIR}"
python3 - <<'PY'
import os, zipfile

stage = "/tmp/App"
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
