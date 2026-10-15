#!/usr/bin/env python3
"""Make pinned SAFEGRAM/AyuGram usable with personal Apple-ID sideload signing.

The original TelegramUI AppDelegate requires a shared App Group and stops
launching when the provisioning profile lacks that entitlement. Free sideload
signing typically cannot grant an App Group. Use private Application Support
storage as a fallback; retain the shared container for fully entitled builds.
"""
from __future__ import annotations

import argparse
from pathlib import Path

TARGET = Path("submodules/TelegramUI/Sources/AppDelegate.swift")
MARKER = "SAFEGRAM: sideload storage fallback (no App Group entitlement)"

OLD_GUARD = """        guard let appGroupUrl = maybeAppGroupUrl else {
            self.mainWindow?.presentNative(UIAlertController(title: nil, message: "Error 2", preferredStyle: .alert))
            return true
        }
"""

NEW_GUARD = """        // SAFEGRAM: sideload storage fallback (no App Group entitlement).
        // Signed App Groups work as before. Only unentitled sideload builds
        // use private, app-sandboxed Application Support; no files are exposed
        // to extensions or other apps through this fallback.
        let appGroupUrl: URL
        if let sharedContainerUrl = maybeAppGroupUrl {
            appGroupUrl = sharedContainerUrl
        } else {
            let localContainerUrl = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0].appendingPathComponent("SAFEGRAM-LocalContainer", isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: localContainerUrl, withIntermediateDirectories: true
                )
                appGroupUrl = localContainerUrl
            } catch {
                self.mainWindow?.presentNative(UIAlertController(
                    title: "SAFEGRAM",
                    message: "The app cannot create its private storage.",
                    preferredStyle: .alert
                ))
                return true
            }
        }
"""

OLD_URL_SESSION = """        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sharedContainerIdentifier = appGroupName
        configuration.isDiscretionary = false
"""

NEW_URL_SESSION = """        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        // An unentitled personal sideload profile cannot use an App Group.
        // Background transfers use their normal per-app sandbox in that case.
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) != nil {
            configuration.sharedContainerIdentifier = appGroupName
        }
        configuration.isDiscretionary = false
"""


def patch_source(source: str) -> str:
    if MARKER in source:
        if NEW_GUARD not in source or NEW_URL_SESSION not in source:
            raise ValueError("partial or modified SAFEGRAM sideload patch")
        return source
    if source.count(OLD_GUARD) != 1:
        raise ValueError("pinned App Group startup guard not found exactly once")
    if source.count(OLD_URL_SESSION) != 1:
        raise ValueError("pinned App Group background session setup not found exactly once")
    changed = source.replace(OLD_GUARD, NEW_GUARD, 1)
    changed = changed.replace(OLD_URL_SESSION, NEW_URL_SESSION, 1)
    assert '"Error 2"' not in changed
    return changed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("upstream_root", type=Path)
    args = parser.parse_args()
    file = args.upstream_root / TARGET
    if not file.is_file():
        raise SystemExit(f"pinned upstream file not found: {file}")
    before = file.read_text(encoding="utf-8")
    after = patch_source(before)
    if after != before:
        file.write_text(after, encoding="utf-8")
    print("SAFEGRAM sideload App Group fallback: OK" +
          (" (already present)" if after == before else ""))


if __name__ == "__main__":
    main()
