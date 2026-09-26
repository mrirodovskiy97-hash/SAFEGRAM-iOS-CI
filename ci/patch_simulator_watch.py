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
