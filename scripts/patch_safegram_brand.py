#!/usr/bin/env python3
"""Patch user-facing SAFEGRAM branding in the pinned AyuGram tree, idempotently."""
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_safegram_brand.py /path/to/Ayugram-iOS")

root = Path(sys.argv[1]).resolve()
backup_root = root / ".safegram-compat-backup"


def require(path: Path) -> Path:
    if not path.is_file():
        raise SystemExit(f"missing expected upstream file: {path}")
    return path


def backup_once(path: Path) -> None:
    rel = path.relative_to(root)
    dst = backup_root / rel
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label} anchor missing")
    backup_once(path)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


build_file = require(root / "Telegram/BUILD")
localizable = require(root / "Telegram/Telegram-iOS/en.lproj/Localizable.strings")
info_strings = require(root / "Telegram/Telegram-iOS/en.lproj/InfoPlist.strings")
localization_manager = require(root / "Swiftgram/SGStrings/Sources/LocalizationManager.swift")
paywall = require(root / "Swiftgram/SGPayWall/Sources/SGPayWall.swift")

# Main app Info.plist fragment: only change user-visible bundle names, never Bazel target names.
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
if patched != block:
    backup_once(build_file)
    build_file.write_text(text[:start] + patched + text[end:], encoding="utf-8")
elif new_display not in block or new_name not in block:
    raise SystemExit("SAFEGRAM app branding anchors missing or changed upstream")

# English bundled application strings are the compile-time fallback used by onboarding.
for path in (localizable, info_strings):
    value = path.read_text(encoding="utf-8")
    if "Swiftgram" in value:
        backup_once(path)
        path.write_text(value.replace("Swiftgram", "SAFEGRAM"), encoding="utf-8")

# SG strings can be refreshed from Swiftgram upstream at runtime. Normalize the brand
# for the English fallback and Russian UI without touching other locale grammar.
manager_old = """        if let localizedString = findLocalizedString(forKey: key, inLocale: sanitizedLocale) {
            if args.isEmpty {
                return String(format: localizedString)
            } else {
                return String(format: localizedString, arguments: args)
            }
        }
"""
manager_new = """        if let localizedString = findLocalizedString(forKey: key, inLocale: sanitizedLocale) {
            let brandedString: String
            if sanitizedLocale == "en" || sanitizedLocale == "ru" {
                brandedString = localizedString.replacingOccurrences(of: "Swiftgram", with: "SAFEGRAM")
            } else {
                brandedString = localizedString
            }
            if args.isEmpty {
                return String(format: brandedString)
            } else {
                return String(format: brandedString, arguments: args)
            }
        }
"""
replace_once(localization_manager, manager_old, manager_new, "SGLocalizationManager branding")

# One hard-coded paywall title bypasses localization.
replace_once(paywall, 'Text("Swiftgram Pro")', 'Text("SAFEGRAM Pro")', "paywall title")

# Verify the surfaces that must never regress.
build_text = build_file.read_text(encoding="utf-8")
vstart = build_text.find(start_marker)
vend = build_text.find(end_marker, vstart)
vblock = build_text[vstart:vend]
if new_display not in vblock or new_name not in vblock:
    raise SystemExit("SAFEGRAM main app bundle branding patch incomplete")
if old_display in vblock or old_name in vblock:
    raise SystemExit("Swiftgram main app bundle branding remains")

loc_text = localizable.read_text(encoding="utf-8")
required_pairs = (
    ('"Tour.Title1" = "SAFEGRAM";', "onboarding title"),
    ('"Application.Name" = "SAFEGRAM";', "application name"),
)
for marker, label in required_pairs:
    if marker not in loc_text:
        raise SystemExit(f"{label} branding verification failed")
if "Swiftgram" in loc_text:
    raise SystemExit("English Localizable.strings still contains Swiftgram")
if "Swiftgram" in info_strings.read_text(encoding="utf-8"):
    raise SystemExit("English InfoPlist.strings still contains Swiftgram")
if 'brandedString = localizedString.replacingOccurrences(of: "Swiftgram", with: "SAFEGRAM")' not in localization_manager.read_text(encoding="utf-8"):
    raise SystemExit("runtime SG localization branding patch incomplete")
if 'Text("SAFEGRAM Pro")' not in paywall.read_text(encoding="utf-8"):
    raise SystemExit("paywall branding patch incomplete")

print("SAFEGRAM user-facing branding patch: OK")
