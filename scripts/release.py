#!/usr/bin/env python3
"""Check release prerequisites; optionally create and export a signed App Store archive.

This script does not upload builds or submit the app for review.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True).stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", action="store_true", help="Create a signed distribution archive after checks pass")
    parser.add_argument("--export", action="store_true", help="Export the archive as an IPA (also archives)")
    args = parser.parse_args()
    config = json.loads((ROOT / "Release/release-config.json").read_text())
    listing = json.loads((ROOT / "Release/store-listing.json").read_text())
    problems = []
    project = (ROOT / "Flashcards.xcodeproj/project.pbxproj").read_text()
    if "com.apple.product-type.bundle.ui-testing" not in project:
        problems.append("Restore the FlashcardsUITests target before running release validation.")

    version = run("xcodebuild", "-version")
    match = re.search(r"Xcode (\d+)", version)
    if not match or int(match.group(1)) < 26:
        problems.append("Install/select Xcode 26 or later with the iOS 26 SDK before uploading to App Store Connect.")
    sdk = run("xcrun", "--sdk", "iphoneos", "--show-sdk-version").strip()
    if int(sdk.split(".")[0]) < 26:
        problems.append(f"Selected iOS SDK is {sdk}; an iOS 26 or later SDK is required.")

    team = config["teamID"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        problems.append("Set teamID to your 10-character paid Apple Developer Team ID.")
    for key in ["supportURL", "privacyURL"]:
        url = urlparse(config[key])
        if url.scheme != "https" or not url.netloc or url.netloc.endswith("example.com"):
            problems.append(f"Set {key} to the publicly hosted HTTPS page, then verify it in a browser.")
    for key in ["supportEmail", "copyright", "reviewContactName", "reviewContactEmail", "reviewContactPhone"]:
        if not config[key].strip():
            problems.append(f"Complete {key} in Release/release-config.json.")
    if not config["buildNumber"].isdigit() or int(config["buildNumber"]) < 1:
        problems.append("buildNumber must be a positive integer, higher than any prior uploaded build.")

    identities = run("security", "find-identity", "-v", "-p", "codesigning")
    if "Apple Distribution:" not in identities:
        problems.append("Install an Apple Distribution signing identity or create it in Xcode Accounts.")
    for key, maximum in [("name", 30), ("subtitle", 30), ("promotionalText", 170), ("description", 4000)]:
        if not 0 < len(listing[key]) <= maximum:
            problems.append(f"Store field {key} must contain 1–{maximum} characters.")
    if len(listing["keywords"].encode("utf-8")) > 100:
        problems.append("Store keywords exceed 100 bytes.")
    for name in ["Config/Info.plist", "Flashcards/PrivacyInfo.xcprivacy"]:
        with (ROOT / name).open("rb") as file:
            plistlib.load(file)
    screenshots = ROOT / "Release/Screenshots"
    for device in ["iPhone", "iPad"]:
        if not list((screenshots / device).glob("*.png")):
            problems.append(f"Capture and inspect the {device} screenshots in Release/Screenshots/{device}.")

    if problems:
        print("Release prerequisites still needed:")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print("Local release checks passed. Confirm device testing, public URLs and App Store Connect fields in Release/README.md.")
    if not (args.archive or args.export):
        return 0

    archive = ROOT / "build/Flashies.xcarchive"
    subprocess.run([
        "xcodebuild", "-project", "Flashcards.xcodeproj", "-scheme", "Flashcards",
        "-configuration", "Release", "-destination", "generic/platform=iOS",
        "-archivePath", str(archive), "-allowProvisioningUpdates",
        f"DEVELOPMENT_TEAM={team}", f"CURRENT_PROJECT_VERSION={config['buildNumber']}",
        f"FLASHIES_SUPPORT_URL={config['supportURL']}", f"FLASHIES_PRIVACY_URL={config['privacyURL']}",
        "archive",
    ], cwd=ROOT, check=True)
    if args.export:
        options = ROOT / "build/ExportOptions.plist"
        options.write_bytes(plistlib.dumps({
            "method": "app-store-connect", "destination": "export", "teamID": team,
            "signingStyle": "automatic", "uploadSymbols": True,
            "manageAppVersionAndBuildNumber": False,
        }))
        subprocess.run([
            "xcodebuild", "-exportArchive", "-archivePath", str(archive),
            "-exportPath", str(ROOT / "build/export"), "-exportOptionsPlist", str(options),
            "-allowProvisioningUpdates",
        ], cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(error.returncode)
