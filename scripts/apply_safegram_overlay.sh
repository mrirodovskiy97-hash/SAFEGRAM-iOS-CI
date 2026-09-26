#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo "usage: $0 /path/to/Ayugram-iOS" >&2; exit 2; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/patch_ayugram.py" "$1"
python3 "$SCRIPT_DIR/patch_tabbar_compat.py" "$1"
echo "Next: generate Xcode project with AyuGram's official README instructions, then build simulator first."
