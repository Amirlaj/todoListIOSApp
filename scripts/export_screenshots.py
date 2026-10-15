#!/usr/bin/env python3
"""Export untouched app screenshots from the UI-test result bundle."""
import argparse
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("result", type=Path, help="Completed .xcresult bundle")
parser.add_argument("device", choices=["iPhone", "iPad"])
args = parser.parse_args()
destination = ROOT / "Release/Screenshots" / args.device
destination.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="flashies-screenshots-") as directory:
    export = Path(directory) / "attachments"
    subprocess.run([
        "xcrun", "xcresulttool", "export", "attachments",
        "--path", str(args.result.resolve()), "--output-path", str(export),
        "--test-id", "FlashiesUITests/testStudyFlowAndCaptureScreenshots()",
    ], check=True, stdout=subprocess.DEVNULL)
    count = 0
    for test in json.loads((export / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            # Keep the six library and study screens selected for the store listing.
            match = re.match(r"(0[1-6]-[a-z]+)_", attachment["suggestedHumanReadableName"])
            if not match or attachment["isAssociatedWithFailure"]:
                continue
            source = export / attachment["exportedFileName"]
            header = source.read_bytes()[:26]
            if header[:8] != b"\x89PNG\r\n\x1a\n":
                raise SystemExit("A screenshot was not a PNG")
            width, height = struct.unpack(">II", header[16:24])
            if header[25] in (4, 6):
                raise SystemExit("Screenshots with an alpha channel cannot be uploaded")
            allowed = {(1206, 2622), (1179, 2556)} if args.device == "iPhone" else {(2064, 2752), (2048, 2732)}
            if (width, height) not in allowed:
                raise SystemExit(f"Unexpected screenshot size: {width} × {height}")
            path = destination / (match.group(1) + ".png")
            shutil.copyfile(source, path)
            print(f"{path.relative_to(ROOT)} — {width} × {height}")
            count += 1
    if count != 6:
        raise SystemExit(f"Expected 6 screenshots, found {count}; inspect the UI-test results")
