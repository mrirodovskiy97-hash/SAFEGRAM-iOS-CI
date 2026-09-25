#!/usr/bin/env python3
"""CI-only patch: make Make.py pass --//Telegram:disableProvisioningProfiles for device compile.
This never changes the overlay source distributed to the app; it patches only the cloned upstream tree.
"""
from pathlib import Path
import sys
p = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("build-system/Make/Make.py")
s = p.read_text(encoding="utf-8")
marker = "def build(bazel, arguments):\n"
start = s.find(marker)
if start < 0:
    raise SystemExit("build() not found")
end = s.find("\ndef test(bazel, arguments):", start)
if end < 0:
    raise SystemExit("test() boundary not found")
block = s[start:end]
needle = "    bazel_command_line.set_configuration(arguments.configuration)\n"
if needle not in block:
    raise SystemExit("set_configuration line not found in build()")
insert = needle + "    bazel_command_line.set_disable_provisioning_profiles()  # SAFEGRAM CI unsigned device build\n"
if "SAFEGRAM CI unsigned device build" not in block:
    block = block.replace(needle, insert, 1)
    s = s[:start] + block + s[end:]
    p.write_text(s, encoding="utf-8")
print("unsigned-device patch applied")
