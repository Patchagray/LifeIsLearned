# Handoff 006 verification

Implementation: in-place Your Library / Explore, focused scanner/restore routes, safer public catalog transport, and approval-gated distribution tooling. Public repository/assets remain unapproved and unpublished; see [implementation report](../../HANDOFF_006_IMPLEMENTATION_REPORT.md) for the remaining gates.

Tested implementation commit: `437c368d4755eaffa2fe3bcc077d7cd74787a0b6`. Machine-readable results are in `test-results.json`, with source SHA-256 values in `tested-source-sha256.json`. The evidence commit changes documentation only. [Commands](commands.md) identify the real destinations and local result bundles. [Release manifest](release-manifest.json) intentionally lists zero approved/published book assets.

## Results

- Full native iPhone simulator suite: 92 passed, 1 physical-premium-voice timing test skipped, 0 failures.
- Full affected UI suites: 8 passed on iPhone 16e and 8 passed on iPad (A16), 0 failures on the corrected runs.
- Final network-copy checks: 13 native tests plus the full download/update/offload/restore UI scenario passed on iPhone; the UI scenario also passed on iPad.
- Final accessibility layout and download-flow reruns on the final source: 2 passed on each simulator, 0 failures.
- Python suite: 62 tests passed, including 9 distribution tests. Publication commands/network are mocked in tooling tests.
- Canonical catalog: 50 books, eight shelves, revision 1 valid. Public scaffold: three allowlisted files, 50 planned titles, zero available packages.
- Existing package/project portable checks: 512 passed. This is not book release approval; existing legacy demo timing remains separately documented.
- Debug test build and Release simulator build succeeded. Release binary excludes synthetic discovery origin/title. The final Release rebuild and binary checks passed and are recorded in JSON.

## What the checks establish

Empty local libraries offer Explore; toggles remain in the home navigation; local/remote search and count state remain separate; primary and secondary shelf filters work; native plus dismissal works; scanner ISBN/text matches focus Explore; large text remains scrollable; remote books install/update/offload/restore; manual offloads retain re-import messaging; cards survive relaunch. Native tests cover cache/ETag/rollback, failed integrity/cancel/retry, removed-idea acknowledgement, full learner-state preservation on reinstall, recovery alias regression, packaged narration/offload, and existing lesson progression.

Final screenshot review prompted two refinements: human-readable network failures and a vertical cover/title arrangement at accessibility sizes. Those affected paths were rebuilt and rerun. Tests do not establish subjective physical voice quality, live camera recognition, device background audio, or unauthenticated production downloads.

## Screenshots

All images in `Screenshots/` are **simulator evidence using isolated synthetic fixtures**. No personal device library is included. `screenshots.json` identifies originating test/bundle and original PNG hash. JPEG previews are resized/compressed for repository review; original attachments stay local. Screenshot filenames retaining `h005` inside source attachment names come from reused test cases, executed on H006 code.

Representative states include empty library, Explore details, shelf/search, the simplified plus menu, large text, download progress, offline catalog and focused restore. The index distinguishes earlier full-suite screenshots from final-source reruns; the intermediate details images retain the disclosure-symbol transition that the final polish removed. See the final screenshot index for the complete set.

## Limits and preserved work

Raw logs, videos, result bundles, unapproved candidate book QA and any package files remain outside tracked evidence. Xcode signing configuration, canonical identity manifest, example lesson package, playback engines and storage recovery implementation are byte-for-byte unchanged from baseline; the source hash manifest and Git diff provide the review boundary.

[Physical checklist](PHYSICAL_CHECKLIST.md) remains pending. Existing H005 device acceptance is not promoted to an H006 device pass. No public releases or backend deployment occurred, and no merge was performed.
