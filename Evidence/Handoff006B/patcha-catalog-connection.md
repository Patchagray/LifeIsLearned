# Patcha catalog connection — 2026-10-10

The owner reported that Thanks for the Feedback remained “release unavailable” after refreshing Explore and restarting the app.

## Findings

- The live staging catalog returned HTTP 200 and advertised `thanks-for-the-feedback` revision 1 as available, with the approved 35,139,188-byte package and SHA-256 `8f5fb585250328333c2a171f049c0350755d4df64510714c32918c2456292520`.
- The prior local iPhone Release build at `/tmp/LIL006-device/Build/Products/Release-iphoneos/LifeIsLearned.app` had an empty `DiscoveryCatalogURL`. That configuration displays bundled preview metadata and cannot refresh remote availability.
- Patcha's app data container had no `Library/Caches/Discovery` directory. The installed bundle's configuration was not directly extracted, so the previous local build and absent cache support, but do not independently prove, the installed configuration diagnosis.

## Remediation and verification

Built source commit `444196355a8a97345ee9b955cc84b5fb8ed7a4a3` with the existing Debug staging configuration:

```sh
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/LIL006B-patcha build
/usr/libexec/PlistBuddy -c 'Print :DiscoveryCatalogURL' /tmp/LIL006B-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app/Info.plist
xcrun devicectl device install app --device Patcha /tmp/LIL006B-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app
xcrun devicectl device process launch --device Patcha com.mariosinclair.lifeislearned
```

Build succeeded. The generated Info.plist contains `https://lifeislearned-catalog-staging.marioams2.workers.dev/v1/catalog`. Installation and launch on Patcha iPhone succeeded. Installed over the existing app without uninstalling or modifying learner files. No app source changes or additional test-suite runs were needed; this installs the already-tested staging configuration. Raw build and device logs remain in `/tmp/LIL006B-patcha*`.

Owner observation of Explore/download after this installation is pending. This record does not claim an observed successful device import.
