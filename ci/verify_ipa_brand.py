#!/usr/bin/env python3
"""Verify that a built IPA exposes SAFEGRAM as the main app name."""
from pathlib import Path
import plistlib
import sys
import zipfile

if len(sys.argv) != 2:
    raise SystemExit("usage: verify_ipa_brand.py /path/to/app.ipa")

ipa = Path(sys.argv[1]).resolve()
if not ipa.is_file():
    raise SystemExit(f"IPA not found: {ipa}")

with zipfile.ZipFile(ipa) as archive:
    candidates = [
        name for name in archive.namelist()
        if name.startswith("Payload/")
        and name.endswith(".app/Info.plist")
        and name.count("/") == 2
    ]
    if len(candidates) != 1:
        raise SystemExit(f"expected one main app Info.plist, found {len(candidates)}")
    info = plistlib.loads(archive.read(candidates[0]))

display_name = info.get("CFBundleDisplayName")
bundle_name = info.get("CFBundleName")
if display_name != "SAFEGRAM" or bundle_name != "SAFEGRAM":
    raise SystemExit(
        f"branding mismatch: CFBundleDisplayName={display_name!r}, "
        f"CFBundleName={bundle_name!r}"
    )

print(
    "IPA branding: OK "
    f"(bundle={info.get('CFBundleIdentifier')}, "
    f"version={info.get('CFBundleShortVersionString')}, "
    f"build={info.get('CFBundleVersion')})"
)
