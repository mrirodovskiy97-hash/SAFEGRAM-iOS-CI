#!/usr/bin/env python3
from pathlib import Path
import sys
p = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("build-system/Make/Make.py")
s = p.read_text(encoding="utf-8")
repls = {
    "'--@build_bazel_rules_swift//swift:copt=\"-j{}\"'.format(os.cpu_count() - 1)": "'--@build_bazel_rules_swift//swift:copt=-j{}'.format(os.cpu_count() - 1)",
    "'--@build_bazel_rules_swift//swift:copt=\"-whole-module-optimization\"'": "'--@build_bazel_rules_swift//swift:copt=-whole-module-optimization'",
}
for old, new in repls.items():
    if old not in s:
        raise SystemExit(f"expected Swift Bazel option not found: {old}")
    s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("Bazel Swift option compatibility patch applied")
