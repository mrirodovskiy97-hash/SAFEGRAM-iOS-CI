#!/usr/bin/env python3
"""CI-only: allow rules_apple to package an unsigned device bundle."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_rules_apple_unsigned.py /path/to/Ayugram-iOS")
root = Path(sys.argv[1]).resolve()
p = root / "build-system/bazel-rules/rules_apple/apple/internal/partials/provisioning_profile.bzl"
if not p.is_file():
    raise SystemExit(f"rules_apple provisioning partial not found: {p}")
s = p.read_text(encoding="utf-8")
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
    p.write_text(s, encoding="utf-8")
print("rules_apple unsigned-device packaging patch: OK")
