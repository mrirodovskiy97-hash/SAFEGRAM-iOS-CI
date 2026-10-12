#!/usr/bin/env python3
"""Generate an unsigned iPhone build config without exposing Telegram secrets in logs."""
from __future__ import annotations

import argparse
import json
import os
import re
import stat
from pathlib import Path


def prepare(environ: dict[str, str], output: Path, status_file: Path) -> str:
    api_id = environ.get("TELEGRAM_API_ID", "").strip()
    api_hash = environ.get("TELEGRAM_API_HASH", "").strip()
    if bool(api_id) != bool(api_hash):
        raise ValueError("both TELEGRAM_API_ID and TELEGRAM_API_HASH must be set together")

    if api_id:
        if not api_id.isascii() or not api_id.isdecimal() or int(api_id) <= 0:
            raise ValueError("TELEGRAM_API_ID must be a positive decimal number")
        if re.fullmatch(r"[0-9a-fA-F]{32}", api_hash) is None:
            raise ValueError("TELEGRAM_API_HASH must be a 32-character hexadecimal value")
        mode = "OWN_TELEGRAM_APP"
    else:
        if environ.get("REQUIRE_OWN_TELEGRAM_CREDENTIALS", "").lower() in ("1", "true", "yes"):
            raise ValueError("own Telegram API credentials are required for this run")
        api_id = environ["CI_API_ID"]
        api_hash = environ["CI_API_HASH"]
        mode = "TELEGRAM_TEST_ONLY"

    bundle_id = environ.get("SAFEGRAM_BUNDLE_ID", "").strip() or "com.safegram.sideload"
    if re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id) is None:
        raise ValueError("SAFEGRAM_BUNDLE_ID has invalid syntax")

    template = Path(__file__).resolve().parents[1] / "config" / "safegram_development_configuration.template.json"
    data = json.loads(template.read_text(encoding="utf-8"))
    data.update(api_id=api_id, api_hash=api_hash,
                team_id=environ.get("CI_TEAM_ID", "0000000000"),
                bundle_id=bundle_id, app_specific_url_scheme="safegram")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    output.chmod(stat.S_IRUSR | stat.S_IWUSR)
    status = (
        f"DEVICE_CREDENTIAL_MODE={mode}\n"
        "IPHONE_INSTALLATION=NOT_VERIFIED\n"
        "TELEGRAM_LOGIN=NOT_VERIFIED\n"
        "IPA_CODESIGNING=UNSIGNED\n"
        "APP_SOURCE=SAFEGRAM_V04_PINNED_UPSTREAM\n"
    )
    status_file.write_text(status, encoding="utf-8")
    env_file = environ.get("GITHUB_ENV", "").strip()
    if env_file:
        with Path(env_file).open("a", encoding="utf-8") as dest:
            dest.write(f"DEVICE_CREDENTIAL_MODE={mode}\n")
    return mode


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--status-output", type=Path, required=True)
    options = parser.parse_args()
    try:
        mode = prepare(os.environ, options.output, options.status_output)
    except (ValueError, KeyError) as exc:
        raise SystemExit(f"SAFEGRAM device config rejected: {exc}") from None
    print(f"SAFEGRAM device credential mode: {mode} (no secret values printed)")


if __name__ == "__main__":
    main()
