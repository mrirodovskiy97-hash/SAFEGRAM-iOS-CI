#!/usr/bin/env python3
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
target = sys.argv[2] if len(sys.argv) > 2 else "16.4"
path = root / "versions.json"
if not path.exists():
    raise SystemExit(f"versions.json not found: {path}")

data = json.loads(path.read_text(encoding="utf-8"))
old = str(data.get("xcode", ""))
if not old:
    raise SystemExit("xcode version missing in versions.json")
data["xcode"] = target
path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
print(f"Xcode requirement patched: {old} -> {target}")
