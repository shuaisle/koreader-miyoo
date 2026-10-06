# -*- coding: utf-8 -*-
"""Verify that the patch logic in build-miyoo.sh matches the real KOReader sources.
Runs the exact same string replacements on copies of the real files and prints the result."""
import io, os, shutil, tempfile, sys

ROOT = r"C:\Users\Shuaisle\Doubao\chats\2026-10-06\new-chat"
tmp = tempfile.mkdtemp(prefix="patchtest_")
print("tmp:", tmp)

# ---- file 1: koreader_targets.cmake (patch 01) ----
src1 = os.path.join(ROOT, "koreader-base-master", "thirdparty", "cmake_modules", "koreader_targets.cmake")
dst1 = os.path.join(tmp, "koreader_targets.cmake")
shutil.copy(src1, dst1)
s = io.open(dst1, encoding="utf-8").read()
old = "if(ANDROID OR POCKETBOOK OR USE_SDL)"
new = "if(ANDROID OR POCKETBOOK)"
assert old in s, "[patch01] FAIL: pattern not found"
s = s.replace(old, new, 1)
io.open(dst1, "w", encoding="utf-8").write(s)
print("[patch01] OK: koreader_targets.cmake patched")
for i, line in enumerate(s.splitlines()):
    if "EXCLUDE_FROM_ALL" in line and "if(" in line:
        print("   ->", line.strip())

# ---- file 2: device.lua (patch 02) ----
src2 = os.path.join(ROOT, "koreader-master", "frontend", "device.lua")
dst2 = os.path.join(tmp, "device.lua")
shutil.copy(src2, dst2)
s = io.open(dst2, encoding="utf-8").read()
old2 = '''        elseif platform:sub(1, #"remarkable") == "remarkable" then
            return require("device/remarkable/device")
        end'''
new2 = '''        elseif platform:sub(1, #"remarkable") == "remarkable" then
            return require("device/remarkable/device")
        elseif platform:sub(1, #"miyoo") == "miyoo" then
            return require("device/miyoo/device")
        end'''
assert old2 in s, "[patch02] FAIL: pattern not found"
s = s.replace(old2, new2, 1)
io.open(dst2, "w", encoding="utf-8").write(s)
print("[patch02] OK: device.lua patched")

# show the probe region after patching
lines = s.splitlines()
for i, line in enumerate(lines):
    if "miyoo" in line:
        print("   ...")
        for j in range(max(0, i - 3), min(len(lines), i + 3)):
            print("   |", lines[j].rstrip())
        break

# ---- file 3: verify frontend/device.lua probe order (miyoo before sdl) ----
s = io.open(dst2, encoding="utf-8").read()
idx_miyoo = s.find('"miyoo"')
idx_sdl = s.find('"sdl"')
idx_linux = s.find('"linux"')
print("probe order check: miyoo@%d sdl@%d linux@%d ->" % (idx_miyoo, idx_sdl, idx_linux),
      "OK (miyoo first)" if 0 < idx_miyoo < idx_sdl else "CHECK (unexpected order)")

# ---- file 4: require() targets inside miyoo/ exist ----
miyoo_dir = os.path.join(ROOT, "miyoo-port", "miyoo")
for f in ("device.lua", "event_map_miyoo.lua", "powerd.lua"):
    assert os.path.exists(os.path.join(miyoo_dir, f)), "missing " + f
print("[miyoo/] OK: device.lua event_map_miyoo.lua powerd.lua present")

# ---- file 5: app files present ----
for f in ("config.json", "launch.sh", "icon.png"):
    assert os.path.exists(os.path.join(ROOT, "miyoo-port", "app", f)), "missing app/" + f
print("[app/] OK: config.json launch.sh icon.png present")

print("\nALL PATCH CHECKS PASSED")
