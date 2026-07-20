# Salah

Salah is a free, privacy-first, open-source iPhone application for prayer timings, fasting events, optional local reminders, and private prayer tracking.

## Requirements

- Xcode 26 or a compatible Xcode release with the iOS 17 SDK
- iOS 17 or later
- An iPhone simulator or signed iPhone target

## Build and run

1. Open `Salah.xcodeproj` in Xcode.
2. Select the shared `Salah` scheme and an iPhone destination.
3. Run with Command-R.

The app does not require an account. Choose a bundled Bangladesh district or allow one-shot When In Use location access. Network prayer-time requests use AlAdhan; cached timings and the local SwiftData tracker remain available offline.

Run deterministic tests without a live network connection:

```sh
xcodebuild -project Salah.xcodeproj -scheme Salah \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

## Architecture

- `App`: dependency container, routing, app entry, and test configuration
- `Core`: Core Location, local notification scheduling, network status, shared presentation
- `Domain`: prayer, date, cache-key, tracker, and insight rules
- `Data`: AlAdhan DTO/client/repository, memory/disk cache, SwiftData persistence
- `Features`: onboarding, Today, Calendar, Tracker/History, reminders, settings, privacy, and about
- `Resources`: districts, privacy manifest/policy, localization catalog, and release notes

Prayer timings vary by method, madhab, adjustments, conditions, and local authority. Confirm timings with an appropriate local authority when necessary.

The project is released under the MIT License. For support, contact the maintainer through the project links in the app.
