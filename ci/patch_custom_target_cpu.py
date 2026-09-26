#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_custom_target_cpu.py /path/to/Make.py")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "# SAFEGRAM CI custom target simulator cpu"
if marker not in text:
    anchor = "        combined_arguments += self.configuration_args\n\n        print('TelegramBuild: running')"
    patch = "        combined_arguments += self.configuration_args\n\n        # SAFEGRAM CI custom target simulator cpu\n        if self.custom_target is not None and '--ios_multi_cpus=sim_arm64' in self.configuration_args:\n            combined_arguments += ['--cpu=ios_sim_arm64']\n\n        print('TelegramBuild: running')"
    if anchor not in text:
        raise SystemExit("custom target CPU patch anchor missing")
    text = text.replace(anchor, patch, 1)
    path.write_text(text, encoding="utf-8")
print("SAFEGRAM custom target simulator CPU patch: OK")
