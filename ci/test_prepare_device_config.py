#!/usr/bin/env python3
"""Static regression tests for SAFEGRAM unsigned device credential handling."""
from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from ci.prepare_device_config import prepare


class DeviceConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.output = Path(self.tmp.name) / "device.json"
        self.status = Path(self.tmp.name) / "status.txt"
        self.env = {
            "CI_API_ID": "17349",
            "CI_API_HASH": "344583e45741c457fe1862106095a5eb",
            "CI_TEAM_ID": "0000000000",
        }

    def test_compile_only_marked_explicitly(self):
        mode = prepare(self.env, self.output, self.status)
        self.assertEqual(mode, "TELEGRAM_TEST_ONLY")
        obj = json.loads(self.output.read_text())
        self.assertEqual(obj["api_id"], self.env["CI_API_ID"])
        self.assertIn("DEVICE_CREDENTIAL_MODE=TELEGRAM_TEST_ONLY", self.status.read_text())
        self.assertIn("TELEGRAM_LOGIN=NOT_VERIFIED", self.status.read_text())
        self.assertIn("IPA_CODESIGNING=UNSIGNED", self.status.read_text())

    def test_own_keys_use_both_without_public_status_leak(self):
        env = {**self.env, "TELEGRAM_API_ID": "1234567",
               "TELEGRAM_API_HASH": "a" * 32}
        mode = prepare(env, self.output, self.status)
        self.assertEqual(mode, "OWN_TELEGRAM_APP")
        self.assertEqual(json.loads(self.output.read_text())["api_hash"], "a" * 32)
        self.assertNotIn("a" * 32, self.status.read_text())
        self.assertNotIn("1234567", self.status.read_text())
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o600)

    def test_partial_secrets_are_rejected(self):
        for key in ("TELEGRAM_API_ID", "TELEGRAM_API_HASH"):
            with self.subTest(key=key):
                with self.assertRaises(ValueError):
                    prepare({**self.env, key: "1234567" if key.endswith("ID") else "a" * 32},
                            self.output, self.status)

    def test_invalid_hash_rejected(self):
        with self.assertRaises(ValueError):
            prepare({**self.env, "TELEGRAM_API_ID": "1234567",
                     "TELEGRAM_API_HASH": "not_a_real_hash"}, self.output, self.status)

    def test_require_own_keys_rejects_test_only(self):
        with self.assertRaises(ValueError):
            prepare({**self.env, "REQUIRE_OWN_TELEGRAM_CREDENTIALS": "true"},
                    self.output, self.status)

    def test_invalid_bundle_id_rejected(self):
        with self.assertRaises(ValueError):
            prepare({**self.env, "SAFEGRAM_BUNDLE_ID": "com.safegram; bad"},
                    self.output, self.status)


if __name__ == "__main__":
    unittest.main()
