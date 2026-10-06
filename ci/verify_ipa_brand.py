#!/usr/bin/env python3
"""Verify that a built IPA exposes SAFEGRAM branding in bundle metadata and UI resources."""
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

    info_path = candidates[0]
    app_prefix = info_path.removesuffix("Info.plist")
    info = plistlib.loads(archive.read(info_path))

    localizable_path = app_prefix + "en.lproj/Localizable.strings"
    try:
        localizable = plistlib.loads(archive.read(localizable_path))
    except KeyError as exc:
        raise SystemExit(f"missing bundled localization: {localizable_path}") from exc

display_name = info.get("CFBundleDisplayName")
bundle_name = info.get("CFBundleName")
if display_name != "SAFEGRAM" or bundle_name != "SAFEGRAM":
    raise SystemExit(
        f"branding mismatch: CFBundleDisplayName={display_name!r}, "
        f"CFBundleName={bundle_name!r}"
    )

required_strings = {
    "Tour.Title1": "SAFEGRAM",
    "Application.Name": "SAFEGRAM",
}
for key, expected in required_strings.items():
    actual = localizable.get(key)
    if actual != expected:
        raise SystemExit(f"branding mismatch: {key}={actual!r}, expected {expected!r}")

for key, value in localizable.items():
    if isinstance(value, str) and "Swiftgram" in value:
        raise SystemExit(f"legacy Swiftgram branding remains in {key}: {value!r}")

print(
    "IPA branding: OK "
    f"(bundle={info.get('CFBundleIdentifier')}, "
    f"version={info.get('CFBundleShortVersionString')}, "
    f"build={info.get('CFBundleVersion')}, "
    f"Tour.Title1={localizable.get('Tour.Title1')!r})"
)
