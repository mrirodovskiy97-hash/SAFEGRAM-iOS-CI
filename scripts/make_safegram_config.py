#!/usr/bin/env python3
"""Generate the flat build config expected by the pinned AyuGram/Swiftgram Make.py."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
TEMPLATE = HERE / "config/safegram_development_configuration.template.json"
DEFAULT_OUT = HERE / "config/safegram_development_configuration.json"

p = argparse.ArgumentParser()
p.add_argument("--api-id", required=True)
p.add_argument("--api-hash", required=True)
p.add_argument("--team-id", required=True)
p.add_argument("--bundle-id", default="com.example.safegram")
p.add_argument("--url-scheme", default="safegram")
p.add_argument("--output", default=str(DEFAULT_OUT))
a = p.parse_args()

if not str(a.api_id).isdigit():
    raise SystemExit("--api-id must be numeric")
if not a.api_hash.strip():
    raise SystemExit("--api-hash is empty")
if not a.team_id.strip():
    raise SystemExit("--team-id is empty")
if not a.bundle_id or "." not in a.bundle_id:
    raise SystemExit("--bundle-id must look like com.name.safegram")

cfg = json.loads(TEMPLATE.read_text(encoding="utf-8"))
cfg["api_id"] = str(a.api_id)
cfg["api_hash"] = a.api_hash.strip()
cfg["team_id"] = a.team_id.strip()
cfg["bundle_id"] = a.bundle_id.strip()
cfg["app_specific_url_scheme"] = a.url_scheme.strip() or "safegram"
out = Path(a.output)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
print(out)
