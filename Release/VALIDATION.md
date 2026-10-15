# Flashies validation

The local-storage update was checked on 15 October 2026 with Xcode 16.2 and the iOS 18.2 SDK. This toolchain can verify the app locally but is too old for current App Store Connect uploads.

## Local storage update — 15 October 2026

- All 53 remaining unit tests pass on iOS 18.0, including library migration, backup restoration, scheduling and reminder permissions. The obsolete test for optional CloudKit relationships was removed.
- All three iPhone UI tests also pass. The result bundle `/tmp/flashies-local-only-tests-20261015.xcresult` reports 56 passed, zero failed and zero skipped tests.
- Both Debug and Release retain the selected development team and automatic signing. The iCloud, Push Notifications and Background Modes capabilities, custom entitlement file and remote-notification background mode have been removed.
- Devices and simulators explicitly use local persistence. The database location and model fields are retained to preserve the existing library.
- Settings, Help, Privacy, store copy, support/privacy page drafts and release scripts now describe local storage and manual file backups.
- The Settings screenshot was visually checked: reminders and About remain, and the sync controls are absent.
- The unsigned arm64 Release archive was rebuilt successfully. Its packaged Info.plist has no background notification mode, and the executable no longer contains the old cloud container identifier. Device provisioning/signing was not validated by this unsigned build.

## Earlier checks — 14 October 2026

- All 54 unit tests pass on iOS 18.0 and on the minimum supported iOS 17.0.
- All three iPhone UI tests pass: module/chapter/card creation with tags and favourites, backup menu and native export-picker access, and studying through Review, Statistics and Settings. The final console log reports `TEST SUCCEEDED`; Xcode reported a separate error saving its result bundle. Earlier successful screenshot attachments were exported before that result-bundle error.
- The study-flow UI test also passes on a 13-inch iPad with no failures or skipped tests; its complete result bundle is `/tmp/flashies-ipad-final.xcresult`.
- Six iPhone screenshots (1206 × 2622) and six iPad screenshots (2064 × 2752) are saved under `Release/Screenshots`. Each was visually inspected and checked for a valid PNG size and no alpha channel. These are unmodified captures of the running app using sample study content.
- An existing on-disk library migrates to the updated models without losing cards, chapter relationships, source files or study progress.
- Chapter and module backups round-trip content, tags, favourites, schedules and review history. Older chapter files still decode; invalid backups do not leave a partially restored module.
- Review intervals, history, accuracy, streaks, tag normalization and reminder permission/scheduling behaviour pass automated checks.
- The unsigned arm64 Release archive built successfully. Its packaged Info.plist identifies the app as Flashies, retains `com.amirlaj.Flashcards`, targets iOS 17+ and includes `ITSAppUsesNonExemptEncryption = false`.
- The archive includes `PrivacyInfo.xcprivacy`. The app icon is a 1024 × 1024 image without an alpha channel.
- Project/plist syntax, release-script syntax and `git diff --check` pass.

The local development archive is at `/tmp/flashies-release/Flashies.xcarchive`. It is unsigned and cannot be uploaded as a distribution build.

## Still required before release

- Rebuild and run the full suite with Xcode 26 or later, including testing on the current iOS release.
- Supply a paid Apple Developer team, distribution signing and App Store Connect app record.
- Verify local persistence and chapter/module backup restoration on a signed device and through TestFlight.
- Verify actual notification delivery on a device, including permission revocation, time changes and restart. Automated reminder checks use an injected notification service.
- Complete and host the privacy/support page drafts; supply support and App Review contacts. Confirm the final privacy, encryption, age-rating, price and territory answers.
- Complete device checks for VoiceOver, large text, dark mode, landscape and long card content.

No build has been uploaded to App Store Connect, sent to TestFlight testers or submitted for App Review. See [the release guide](README.md) for the signing and distribution steps, and run `python3 scripts/release.py` to list outstanding local prerequisites.
