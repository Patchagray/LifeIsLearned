# Handoff 002 — physical-device deployment and acceptance

Date: October 4, 2026. Branch: `feature/handoff-002-ui-polish`.

Deployed commit: [`f4a8693645c3e97a54567f1034f4d463b6506fb3`](https://github.com/Patchagray/LifeIsLearned/commit/f4a8693645c3e97a54567f1034f4d463b6506fb3). Its app implementation matches simulator-tested commit `12ec69ad440384531e2ee9bad7c3b65a8ed0ea0a`; the intervening commit only published documentation and evidence.

## Agent-observed deployment

| Item | Observed result |
| --- | --- |
| Device | Connected iPhone 15 Pro Max; available over USB |
| Operating system | iOS 27.2 (24B5089g) |
| Toolchain | Xcode 26.5 (17F42) |
| Target | Shared `LifeIsLearned` scheme, Debug, physical iPhone |
| Signing | Existing automatic signing settings used unchanged |
| Build | Exit 0; `** BUILD SUCCEEDED **` |
| Installation | Exit 0; device JSON outcome `success` |
| Launch | Exit 0; device JSON outcome `success`, foreground activation enabled |
| App data | Installed over the existing app; no uninstall or data reset command used |

The build emitted the App Intents metadata warning because the app has no `AppIntents.framework` dependency. No compiler error occurred. The first launch invocation supplied an empty environment dictionary; the CLI rejected that argument before launching. Retrying with the normal environment succeeded. The successful launch had no UI-test storage environment or test arguments.

## User-reported physical checks

After the user took responsibility for physical checks and received the build above, they reported **“All checks are good”** and authorized committing and pushing the work. This is acceptance of that deployed build. No remaining blocker was reported.

This is an overall user report. Individual voice, interruption, accessibility, and other scenario results were not separately enumerated or observed by the agent. Earlier simulator results and screenshots retain their original scope. This acceptance update changes only documentation and evidence; no additional build or tests were run for it.

## Commands

The successful commands below reproduce the recorded invocations with the private device identifier replaced by `$DEVICE_UDID`. Set that variable to the connected phone's identifier from `xcrun xcdevice list --timeout 10`. Run from the repository root. Existing signing settings are used.

```bash
xcrun xcdevice list --timeout 10
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination "platform=iOS,id=$DEVICE_UDID" -derivedDataPath /tmp/LifeIsLearned-Patcha-DerivedData build > /tmp/LifeIsLearned-patcha-build.log 2>&1
xcrun devicectl device install app --device "$DEVICE_UDID" /tmp/LifeIsLearned-Patcha-DerivedData/Build/Products/Debug-iphoneos/LifeIsLearned.app --timeout 120 --json-output /tmp/LifeIsLearned-patcha-install.json --log-output /tmp/LifeIsLearned-patcha-install.log
xcrun devicectl device process launch --device "$DEVICE_UDID" --terminate-existing --timeout 30 --json-output /tmp/LifeIsLearned-patcha-launch.json --log-output /tmp/LifeIsLearned-patcha-launch.log com.mariosinclair.lifeislearned
```

## Local raw evidence

The following files remain on the Mac in `/tmp`. Raw logs include device and signing details and are not committed. Hashes identify the evidence checked when recording acceptance.

| File under `/tmp` | SHA-256 |
| --- | --- |
| `LifeIsLearned-patcha-build.log` | `244f06c59d5f4cc88bae6ba4166d1ebb0d3ac29fd845567f0c71b32a548600d5` |
| `LifeIsLearned-patcha-install.json` | `a11b739229f071b78f8b5663b404f0ff8d7a8c772ca79947d69f9476b01d3b14` |
| `LifeIsLearned-patcha-install.log` | `4026aeb117330be553fb396c612f53c160d62cd663b9570705476e64929ce3c1` |
| `LifeIsLearned-patcha-launch.json` | `4f553f676bd5b4db707f996cd7b33a320bf63eece0dd3ebc780e6b6dd5697fb4` |
| `LifeIsLearned-patcha-launch.log` | `75ceb467bdf2131466439cbcb89b344c608021618f99ffae2cecb83cf233e78b` |
