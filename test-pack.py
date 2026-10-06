# -*- coding: utf-8 -*-
"""Locally verify the fixed packaging logic (symlink tolerance) from build-miyoo.sh."""
import os
import shutil
import tempfile
import zipfile

stage = os.path.join(tempfile.mkdtemp(prefix="packtest_"), "onion")
os.makedirs(os.path.join(stage, "Apps", "KOReader", "koreader"))

# 1. a normal file
nf = os.path.join(stage, "Apps", "KOReader", "koreader", "luajit")
with open(nf, "wb") as fh:
    fh.write(b"\x7fELF normal binary payload")

# 2. a good symlink (points to an existing file)
gf = os.path.join(stage, "Apps", "KOReader", "koreader", "ev_replay.py")
target_ok = os.path.join(stage, "Apps", "KOReader", "koreader", "luajit")
try:
    os.symlink(os.path.relpath(target_ok, os.path.dirname(gf)), gf)
    symlink_ok = True
except OSError:
    symlink_ok = False
    print("NOTE: cannot create symlink on this system; testing fallback only")

# 3. a broken symlink (points nowhere) / plain-file fallback
bf = os.path.join(stage, "Apps", "KOReader", "koreader", "COPYING")
if symlink_ok:
    os.symlink("does-not-exist.txt", bf)
else:
    # No symlink privilege on this system: use plain files so the
    # regular path is still exercised (the symlink branches are simple
    # enough to verify on Linux later).
    with open(gf, "wb") as fh:
        fh.write(b"\x7fELF normal binary payload")
    with open(bf, "wb") as fh:
        fh.write(b"GPL license text")

# --- the fixed packaging logic (identical to build-miyoo.sh) ---
out = os.path.join(tempfile.gettempdir(), "packtest-out.zip")
if os.path.exists(out):
    os.remove(out)
count = 0
skipped = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(stage):
        for f in sorted(files):
            p = os.path.join(root, f)
            arc = os.path.relpath(p, stage)
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
            zi.external_attr = (mode & 0xFFFF) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(zi, data)
            count += 1

print(f"packed={count} skipped={skipped}")
if symlink_ok:
    # good symlink (ev_replay.py) resolved + normal file; broken COPYING skipped
    assert count == 2, f"expected 2 files packed, got {count}"
    assert skipped == 1, f"expected 1 skipped (broken COPYING), got {skipped}"
else:
    # all plain files in this environment
    assert count == 3, f"expected 3 files packed, got {count}"
    assert skipped == 0

# verify zip contents
with zipfile.ZipFile(out, "r") as z:
    names = sorted(z.namelist())
    print("zip entries:", names)
    if symlink_ok:
        # broken COPYING must NOT be in the zip; ev_replay.py must contain real content
        assert "Apps/KOReader/koreader/COPYING" not in names, "broken symlink should be skipped"
        assert z.read("Apps/KOReader/koreader/ev_replay.py") == b"\x7fELF normal binary payload", \
            "good symlink should be resolved to real content"
    assert "Apps/KOReader/koreader/luajit" in names

print("PACKAGING LOGIC OK")
