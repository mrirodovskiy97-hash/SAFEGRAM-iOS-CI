#!/usr/bin/env python3
"""Install and launch the built SAFEGRAM IPA in an available iOS Simulator."""
from pathlib import Path
import argparse
import json
import plistlib
import shutil
import subprocess
import tempfile
import time
import zipfile


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, capture_output=True)


parser = argparse.ArgumentParser()
parser.add_argument("ipa", type=Path)
parser.add_argument("output_dir", type=Path)
args = parser.parse_args()
ipa = args.ipa.resolve()
out = args.output_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
if not ipa.is_file():
    raise SystemExit(f"IPA not found: {ipa}")
if shutil.which("xcrun") is None:
    raise SystemExit("xcrun is required; run this smoke test on macOS with Xcode")

with tempfile.TemporaryDirectory(prefix="safegram-sim-") as td:
    extracted = Path(td)
    with zipfile.ZipFile(ipa) as archive:
        archive.extractall(extracted)
    apps = list((extracted / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise SystemExit(f"expected one .app in IPA, found {len(apps)}")
    app = apps[0]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    bundle_id = info["CFBundleIdentifier"]

    devices_raw = run("xcrun", "simctl", "list", "devices", "available", "-j").stdout
    devices = json.loads(devices_raw).get("devices", {})
    candidates = [
        d for runtime in devices.values() for d in runtime
        if d.get("isAvailable", True) and d.get("name", "").startswith("iPhone")
    ]
    if not candidates:
        (out / "simctl-devices.json").write_text(devices_raw)
        raise SystemExit("no available iPhone Simulator device")

    device = next((d for d in candidates if d.get("state") == "Booted"), candidates[0])
    udid = device["udid"]
    booted_here = device.get("state") != "Booted"
    (out / "simulator-device.txt").write_text(
        f"name={device.get('name')}\nudid={udid}\nbundle={bundle_id}\n"
    )

    try:
        if booted_here:
            run("xcrun", "simctl", "boot", udid, check=False)
        run("xcrun", "simctl", "bootstatus", udid, "-b")
        run("xcrun", "simctl", "install", udid, str(app))
        launch = run("xcrun", "simctl", "launch", udid, bundle_id)
        launch_text = launch.stdout + launch.stderr
        (out / "simulator-launch.txt").write_text(launch_text)
        try:
            pid = int(launch.stdout.strip().rsplit(":", 1)[1].strip())
        except (IndexError, ValueError) as exc:
            raise SystemExit(f"could not parse Simulator launch PID: {launch_text!r}") from exc
        time.sleep(5)

        process = run("ps", "-p", str(pid), "-o", "pid=,comm=", check=False)
        (out / "simulator-process.txt").write_text(process.stdout + process.stderr)
        if process.returncode != 0:
            raise SystemExit(f"{bundle_id} exited within 5 seconds of launch (pid {pid})")

        launchctl = run("xcrun", "simctl", "spawn", udid, "launchctl", "list", check=False)
        (out / "simulator-launchctl.txt").write_text(launchctl.stdout + launchctl.stderr)
        run("xcrun", "simctl", "io", udid, "screenshot", str(out / "simulator-smoke.png"))
        print(f"Simulator smoke: OK ({device.get('name')}, {bundle_id})")
    finally:
        run("xcrun", "simctl", "terminate", udid, bundle_id, check=False)
        if booted_here:
            run("xcrun", "simctl", "shutdown", udid, check=False)
