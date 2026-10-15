#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path

from scripts.patch_sideload_appgroup import (
    MARKER,
    NEW_GUARD,
    NEW_URL_SESSION,
    OLD_GUARD,
    OLD_URL_SESSION,
    patch_source,
)


class SideloadAppGroupPatchTests(unittest.TestCase):
    def setUp(self):
        self.source = (
            "import Foundation\n"
            "func urlSessions() {\n" + OLD_URL_SESSION + "}\n"
            "func application() {\n" + OLD_GUARD + "}\n"
        )

    def test_fallback_preserves_real_app_group_and_uses_private_storage(self):
        result = patch_source(self.source)
        self.assertIn(MARKER, result)
        self.assertIn("if let sharedContainerUrl = maybeAppGroupUrl", result)
        self.assertIn("applicationSupportDirectory", result)
        self.assertIn("createDirectory", result)
        self.assertIn('appendingPathComponent("SAFEGRAM-LocalContainer"', result)
        self.assertNotIn('"Error 2"', result)

    def test_background_session_does_not_assume_app_group_entitlement(self):
        result = patch_source(self.source)
        self.assertIn(NEW_URL_SESSION, result)
        self.assertIn('containerURL(forSecurityApplicationGroupIdentifier: appGroupName) != nil', result)

    def test_idempotent(self):
        once = patch_source(self.source)
        twice = patch_source(once)
        self.assertEqual(once, twice)

    def test_rejects_modified_upstream_guard(self):
        with self.assertRaises(ValueError):
            patch_source(self.source.replace('"Error 2"', '"Error changed"'))

    def test_rejects_duplicate_guards(self):
        with self.assertRaises(ValueError):
            patch_source(self.source + OLD_GUARD)

    def test_rejects_partial_patch(self):
        broken = patch_source(self.source).replace(NEW_URL_SESSION, OLD_URL_SESSION)
        with self.assertRaises(ValueError):
            patch_source(broken)


if __name__ == "__main__":
    unittest.main()
