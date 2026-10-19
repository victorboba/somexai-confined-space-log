# Confined Space Log

An entry permit and atmospheric test log for confined spaces. The entry supervisor drafts a permit, records gas readings, issues it with a drawn signature, tracks who is inside, and cancels and files it.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the collection is [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Spaces**: set up each space once (ID, location, kind, known hazards, isolation points, photo). Every permit for that space starts pre-filled from it.
- **Acceptable entry conditions**: entered by the user from their own written program. The app ships no numbers. A gas left blank has no criterion, which is not the same as zero.
- **Permit lifecycle**: draft, tested, issued, cancelled and filed. A draft cannot act as an issued permit, and the app lists exactly which preconditions are missing before issue.
- **Atmospheric test log**: timestamped readings (oxygen, LEL, CO, H2S and one other gas) with instrument and tester, compared against the recorded criteria. Before-entry tests are required before issue.
- **Entrant roster**: sign in and sign out by name and time. The board shows the live count and the time left on each open permit.
- **Signatures**: drawn by finger for issue and for cancellation.
- **Archive**: cancelled permits with a one-year retention clock.
- **Export**: an entry permit PDF for posting and filing, and CSV export.
- A Home Screen widget, a Siri App Shortcut, and a six-step How do I use guide.

## The boundary

The app makes no safety determination, does not authorize any entry, and does not decide whether conditions are acceptable. Acceptable entry conditions shown are the ones the user recorded from their own program; every screen that compares a reading to them says so.

## Privacy

All data stays on the device in SwiftData. There is no account, no analytics and no network code, and `AppConfig.iCloudSyncEnabled` is `false`. Photos and signatures are stored in the same on-device database. CSV and PDF export happen only when you choose to share a file.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17+.

```bash
xcodegen generate
open ConfinedSpaceLog.xcodeproj
```

Pick the `ConfinedSpaceLog` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme ConfinedSpaceLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

The alternative is `scripts/ci.sh ConfinedSpaceLog`.

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings. In Debug builds, Settings has a Debug section, and the launch arguments `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices` and `-uiTesting` are available.

To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Project layout

- `ConfinedSpaceLog/App/`: app entry point and the root view that gates onboarding, paywall and the app.
- `ConfinedSpaceLog/Core/`: StoreKit entitlement, CSV and PDF export, App Intents, review prompt, widget sync, debug flags and sample data.
- `ConfinedSpaceLog/Features/`: the screens, including onboarding, paywall, settings and the How do I use guide.
- `ConfinedSpaceLog/Models/`: the SwiftData models and the calculation code. Models are `ConfinedSpace`, `Permit`, `GasReading` and `Entrant`; `Core/Signature` holds the signature pad.
- `ConfinedSpaceLog/StoreKit/Products.storekit`: local StoreKit configuration.
- `ConfinedSpaceLogWidget/`: the Home Screen widget, fed by a snapshot in the App Group.
- `ConfinedSpaceLogTests/` and `ConfinedSpaceLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, onboarding, paywall benefits, How-to steps, disclaimer, product IDs, links).
- `scripts/`: icon and screenshot helpers. `docs/` has notes on capabilities such as iCloud and App Groups.

## Technical notes

- `Permit` snapshots the space title and location, so editing or removing a space never rewrites a permit already issued.
- Every property is defaulted and relationships are optional, which keeps the schema CloudKit-compatible.

## License

MIT. See [LICENSE](LICENSE).
