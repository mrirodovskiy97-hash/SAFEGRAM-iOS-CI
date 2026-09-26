#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / "Telegram" / "BUILD"
s = p.read_text(encoding="utf-8")
old = '    watch_application = ":TelegramWatchApp", # MARK: Swiftgram\n'
new = '    watch_application = None, # SAFEGRAM CI simulator: disable Watch target\n'
if new in s:
    print("simulator Watch patch already applied")
elif old in s:
    p.write_text(s.replace(old, new, 1), encoding="utf-8")
    print("simulator Watch patch applied")
else:
    raise SystemExit("Swiftgram watch_application anchor not found")

# Bazel 8 / rules_swift expects raw Swift options, not quote characters.
mp = root / "build-system" / "Make" / "Make.py"
ms = mp.read_text(encoding="utf-8")
repls = {
    '--@build_bazel_rules_swift//swift:copt="-j{}"': '--@build_bazel_rules_swift//swift:copt=-j{}',
    '--@build_bazel_rules_swift//swift:copt="-whole-module-optimization"': '--@build_bazel_rules_swift//swift:copt=-whole-module-optimization',
}
changed = False
for old_arg, new_arg in repls.items():
    if old_arg in ms:
        ms = ms.replace(old_arg, new_arg)
        changed = True
if changed:
    mp.write_text(ms, encoding="utf-8")
print("simulator Swift copt quoting patch applied")
