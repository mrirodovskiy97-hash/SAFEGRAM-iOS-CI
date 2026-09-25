#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/7] Python syntax"
python3 -m py_compile scripts/patch_ayugram.py scripts/make_safegram_config.py tests/test_patch.py

echo "[2/7] Shell syntax"
bash -n scripts/apply_safegram_overlay.sh scripts/bootstrap_from_github.sh scripts/rollback_safegram_overlay.sh scripts/verify_overlay.sh scripts/run_checks.sh

echo "[3/7] Config generator"
TMP_CFG="$(mktemp)"
python3 scripts/make_safegram_config.py --api-id 12345 --api-hash testhash --team-id TEAM123 --bundle-id com.test.safegram --output "$TMP_CFG" >/dev/null
python3 - "$TMP_CFG" <<'PY'
import json, sys
p=sys.argv[1]; d=json.load(open(p)); assert d["app"]["bundle_id"]=="com.test.safegram"; assert d["app"]["app_specific_url_scheme"]=="safegram"
PY
rm -f "$TMP_CFG"

echo "[4/7] Patcher test"
python3 tests/test_patch.py

if command -v swiftc >/dev/null 2>&1; then
    echo "[5/7] Swift parse"
    swiftc -parse overlay/Swiftgram/SafeGramCore/Sources/*.swift overlay/Swiftgram/SafeGramUI/Sources/*.swift
    echo "[6/7] Core Swift typecheck"
    swiftc -warnings-as-errors -typecheck overlay/Swiftgram/SafeGramCore/Sources/*.swift
    echo "[7/7] Core smoke"
    TMP_SMOKE="$(mktemp)"
    trap 'rm -f "$TMP_SMOKE"' EXIT
    swiftc -warnings-as-errors overlay/Swiftgram/SafeGramCore/Sources/*.swift tests/core_smoke.swift -o "$TMP_SMOKE"
    "$TMP_SMOKE"
    echo "SAFEGRAM overlay verification: OK (Swift included)"
else
    echo "SAFEGRAM overlay verification: PARTIAL (Swift compile and smoke BLOCKED: swiftc unavailable)"
fi
