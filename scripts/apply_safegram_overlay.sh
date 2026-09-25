#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo "usage: $0 /path/to/Ayugram-iOS" >&2; exit 2; fi
python3 "$(cd "$(dirname "$0")" && pwd)/patch_ayugram.py" "$1"
echo "Next: generate Xcode project with AyuGram's official README instructions, then build simulator first."
