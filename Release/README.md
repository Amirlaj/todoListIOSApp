# Flashies release preparation

The source is prepared for an iPhone/iPad release. Upload and publication still require the owner's Apple Developer account, signing, hosted support/privacy pages and verification on signed devices. The local Xcode 16.2 build is for development verification only: Apple requires Xcode 26 or later and the iOS 26 SDK for uploads from 28 April 2026. [Apple's current SDK requirement](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)

## Release files

- `VALIDATION.md`: completed local checks and the remaining device/distribution checks.
- `store-listing.json`: store description, keywords, review notes and TestFlight testing notes.
- `release-config.json`: owner-supplied team, contact details, public URLs and build number. Empty fields are intentional blockers, not publishable defaults.
- `privacy-policy.html` and `support.html`: page drafts. Add the owner's contact information, remove the draft notices, host them over HTTPS, and put the final URLs in `release-config.json`.
- `Screenshots/iPhone` and `Screenshots/iPad`: screenshots captured from the running app by UI tests.
- `../scripts/release.py`: prerequisite check, signed archive and IPA export. It never uploads or submits a build automatically.

To refresh screenshots, run `FlashiesUITests/testStudyFlowAndCaptureScreenshots` on an iPhone 16 Pro and a 13-inch iPad simulator, then use `python3 scripts/export_screenshots.py /path/to/result.xcresult iPhone` (or `iPad`). This extracts the six unmodified library and study screenshots selected for the listing and checks their dimensions and lack of an alpha channel.

## Apple account and signing

1. Use an active paid Apple Developer membership. Sign into Xcode's Accounts settings and select the team for the Flashcards target.
2. Register the existing bundle ID `com.amirlaj.Flashcards`. Keeping this identifier preserves the identity of existing local builds. The installed display name is Flashies. The app uses local storage and local reminders and does not require additional signing capabilities.
3. Create an Apple Distribution certificate and let Xcode manage the provisioning profile. Do not put certificates, passwords or private keys in this repository.
4. Create the Flashies iOS app in App Store Connect using the same bundle ID. Confirm name availability, primary language, SKU, content rights, age-rating answers, price and territories. The suggested store listing is free; no payment or advertising code is included.

## Verify local storage and backups

Device and simulator builds use the same local SwiftData store configuration. The store location and model fields are retained so an update can open the existing library.

1. Add a sample module, import a file, add tags/favourites and record a review. Relaunch the app and confirm that the library and progress remain available offline.
2. Export a chapter and a complete module. Restore each with and without progress, confirming that imports create separate copies.
3. Transfer an exported file to another device through Files and import it there. Each device keeps its own library; edits are not synchronized automatically.
4. Repeat these checks with the signed TestFlight build before release.

## Privacy and review information

The app has no ad, analytics, tracking, account-registration or AI SDK. Card content and review data are stored in the local library; exported files are saved wherever the user chooses in Files. The privacy manifest declares app-local UserDefaults access (`CA92.1`). System encryption only is used, and `ITSAppUsesNonExemptEncryption` is false.

The proposed App Privacy response is “Data Not Collected” for this implementation, based on the absence of developer-readable storage, tracking and analytics. The owner must confirm this against the final distribution setup and support practices. Reassess the declaration if you add analytics, crash SDKs, accounts, AI or a backend. [Apple's data-collection definition](https://developer.apple.com/app-store/app-privacy-details/)

Supply a public privacy-policy URL and a support URL with working contact details, plus private App Review contact information. The local drafts must not be published with their draft notices or missing contacts. [Privacy URL requirement](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [Support contact requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

The app contains educational sample cards and private user-authored text, with no public feed, messaging, ads, payments or unrestricted web browsing. Answer the current age-rating questionnaire from those actual capabilities; do not claim a Kids Category designation without reviewing its additional requirements.

## Build and distribute

Install/select Xcode 26 or later, complete `release-config.json`, and inspect the screenshots. Increment `buildNumber` for each upload.

```sh
python3 scripts/release.py
python3 scripts/release.py --archive
python3 scripts/release.py --export
```

The signed archive is written to `build/Flashies.xcarchive`; the exported IPA is under `build/export`. Open the archive in Xcode Organizer, validate it, then use Distribute App → App Store Connect → Upload (or upload the exported IPA with Transporter). Confirm the processed build's signing, app icon and privacy manifest.

For TestFlight, complete beta information and feedback contact details, select the processed build and add an internal tester group. External testing may require Beta App Review. For the App Store, attach the tested build, complete screenshots and all metadata, select manual release if desired, and submit for App Review. Nothing has been uploaded or submitted by the local preparation workflow. [TestFlight workflow](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Final checks

- Run the full test suite on Xcode 26 and the oldest supported iOS version (17), as well as the current iOS release.
- Verify local storage, backup restoration and notification delivery on a signed device, including denied permission, time changes, device restart and notification permission revoked in Settings.
- Inspect iPhone and iPad screenshots, large text, VoiceOver, dark mode, landscape, empty libraries and long card content.
- Import malformed and older chapter files; restore a full module with and without progress. Ensure existing data survives an update.
- Confirm public support/privacy URLs work without authentication and that App Store contact, privacy, encryption and age-rating answers match the shipping app.
- Check current screenshot specifications in App Store Connect. The captured iPhone 16 Pro and iPad Pro 13-inch images are real simulator screenshots. [Apple screenshot sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
