# Narration scrolling — simulator evidence

`results.json` contains sanitized XCTest summaries and SHA-256 hashes of the production source tested. Raw logs and result bundles remain locally at the recorded `/tmp` paths.

The before/after images show the actual `ReaderView`, hosted at 820 × 1180 points on the iPad (A16) simulator with Dynamic Type set to accessibility3. The test injects the final word range into the narration text component to demonstrate that a previously hidden line becomes visible. Audio is inactive in this fixture, so the playback controls say “Your pace.” These images do not constitute a physical-device or live-voice test.

The agent visually reviewed these images and an iPhone large-text pair retained in the local test results. Portrait, landscape, and tablet-sized text geometry is also covered by assertions in `NarrationScrollingTests`.
