#!/usr/bin/env python3
"""Patch the pinned AyuGram Bazel app plist branding to SAFEGRAM, idempotently."""
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_safegram_brand.py /path/to/Ayugram-iOS")

root = Path(sys.argv[1]).resolve()
build_file = root / "Telegram/BUILD"
if not build_file.is_file():
    raise SystemExit(f"missing expected upstream file: {build_file}")

text = build_file.read_text(encoding="utf-8")
start_marker = 'plist_fragment(\n    name = "TelegramInfoPlist",'
end_marker = "\n)\n\nlocal_provisioning_profile("
start = text.find(start_marker)
if start < 0:
    raise SystemExit("TelegramInfoPlist anchor missing")
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit("TelegramInfoPlist end anchor missing")

block = text[start:end]
old_display = "<key>CFBundleDisplayName</key>\n    <string>Swiftgram</string>"
new_display = "<key>CFBundleDisplayName</key>\n    <string>SAFEGRAM</string>"
old_name = "<key>CFBundleName</key>\n    <string>Swiftgram</string>"
new_name = "<key>CFBundleName</key>\n    <string>SAFEGRAM</string>"

patched = block.replace(old_display, new_display, 1).replace(old_name, new_name, 1)
if patched == block:
    if new_display not in block or new_name not in block:
        raise SystemExit("SAFEGRAM app branding anchors missing or changed upstream")
else:
    backup = root / ".safegram-compat-backup/Telegram/BUILD"
    if not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(build_file, backup)
    text = text[:start] + patched + text[end:]
    build_file.write_text(text, encoding="utf-8")

verify = build_file.read_text(encoding="utf-8")
vstart = verify.find(start_marker)
vend = verify.find(end_marker, vstart)
vblock = verify[vstart:vend]
if new_display not in vblock or new_name not in vblock:
    raise SystemExit("SAFEGRAM app branding patch incomplete")
if old_display in vblock or old_name in vblock:
    raise SystemExit("Swiftgram main app branding remains")

print("SAFEGRAM main app branding patch: OK")
