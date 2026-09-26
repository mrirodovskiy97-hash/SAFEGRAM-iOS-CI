#!/usr/bin/env python3
"""CI-only: allow rules_apple to package an unsigned device bundle."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_rules_apple_unsigned.py /path/to/Ayugram-iOS")
root = Path(sys.argv[1]).resolve()
profile = root / "build-system/bazel-rules/rules_apple/apple/internal/partials/provisioning_profile.bzl"
codesign = root / "build-system/bazel-rules/rules_apple/apple/internal/codesigning_support.bzl"
for p in (profile, codesign):
    if not p.is_file():
        raise SystemExit(f"rules_apple file not found: {p}")

s = profile.read_text(encoding="utf-8")
marker = "SAFEGRAM CI unsigned device: no embedded provisioning profile"
if marker not in s:
    start = s.find("    if not profile_artifact:\n")
    end = s.find("    # Create intermediate file", start)
    if start < 0 or end < 0:
        raise SystemExit("rules_apple provisioning-profile anchor not found")
    replacement = (
        "    if not profile_artifact:\n"
        f"        # {marker}\n"
        "        return struct(bundle_files = [])\n\n"
    )
    s = s[:start] + replacement + s[end:]
    profile.write_text(s, encoding="utf-8")

c = codesign.read_text(encoding="utf-8")
marker2 = "SAFEGRAM CI unsigned device: allow ad-hoc device signing without profile"
if marker2 not in c:
    anchor = "def _validate_provisioning_profile(\n"
    start = c.find(anchor)
    body = c.find("    # Verify that a provisioning profile was provided for device builds on\n", start)
    if start < 0 or body < 0:
        raise SystemExit("rules_apple codesigning validation anchor not found")
    insertion = (
        f"    # {marker2}\n"
        "    if platform_prerequisites.platform.is_device and not provisioning_profile:\n"
        "        return\n"
    )
    c = c[:body] + insertion + c[body:]
    codesign.write_text(c, encoding="utf-8")

print("rules_apple unsigned-device packaging patch: OK")
