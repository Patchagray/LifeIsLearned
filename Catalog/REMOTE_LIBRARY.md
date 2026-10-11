# Handoff 006B update

H006B supersedes the public GitHub distribution proposal. Explore uses the reviewer-configured HTTPS Cloudflare catalog endpoint, backed by PRIVATE `Patchagray/LifeIsLearned-Published`. No package or cover is approved at bootstrap. See [Worker operations](../Backend/CatalogWorker/README.md) and [private release gates](../ReleaseGate/README.md). The notes below retain prior implementation history.

# Handoff 006 update

Explore now lives in the home library section. The shipped public endpoint, origin policy, ETag caching and separate distribution repository supersede the unconfigured H005 preview below. See [public distribution operations](PUBLIC_DISTRIBUTION.md). The request backend remains separately configured. H005's historical implementation notes follow.

# Discovery catalog contract (Handoff 005C)

`Remote-Catalog-001.json` is schemaVersion 1, catalogID `catalog-001`, catalogRevision **1**. The catalogRevision refers to the approved identity contract; availability can refresh without changing that contract. Other schema/identity revisions are rejected until explicitly approved. All 50 stable IDs and shelf assignments come from Catalog 001. `CollectionCatalog` remains installed learner state.

The initial checked-in catalog lists **planned** releases. It makes no claim that a title has a publicly downloadable, approved package. Empty ISBN arrays mean unreviewed/not supplied, not fabricated identifiers.

- `available`: package required, with positive collectionRevision, HTTPS URL, exact raw-file SHA-256, positive bytes ≤64 MiB.
- `planned`: Coming Soon (request entry added in 005D).
- `unavailable`: Request (client/backend entry added in 005D).
- Optional thumbnail: separate HTTPS URL, SHA-256, bytes ≤512 KiB, native-decodable single-frame PNG/JPEG ≤2048×2048.
- Metadata document ≤2 MiB. No public request counts.
- Identity/shelf validation runs before cache replacement. Offline/malformed refresh retains the last good cache. Refresh can be cancelled; opening the installed library does not wait for it.

## Release preparation (reviewer controlled)

Generate metadata from the final local JSON without rewriting IDs or publishing:

```sh
python3 Tools/remote_catalog_metadata.py path/to/book.json \
  --url https://github.com/Patchagray/LifeIsLearned-Catalog/releases/download/APPROVED_TAG/book.json \
  --thumbnail path/to/cover.jpg --thumbnail-url https://example.org/cover.jpg
```

Add `--verify-catalog Catalog/Remote-Catalog-001.json` to require the matching existing entry to equal the computed metadata.

This verifies package structure, identity, size and hash. It does **not** certify source review, premium voice release timing, or illustration editorial approval. Those gates still apply. Review the output and use it in the catalog only after the approved assets are published. Do not edit the final JSON after hashing. Package format remains 2 and contains no GitHub transport assumptions.

## Configuration

Xcode user-defined build settings `LIL_DISCOVERY_CATALOG_URL` and `LIL_BOOK_REQUEST_API_URL` expand the App-Info.plist keys `DiscoveryCatalogURL` / `BookRequestAPIURL`. Both are empty by default. Set once in a reviewer-controlled local xcconfig/build invocation; HTTPS only, no embedded credentials. No app GitHub write token or backend admin secret. A missing endpoint shows the bundled editorial preview honestly.

## Download/install boundary

URLSession download tasks stage files outside durable learner snapshots, report byte progress, cancel, and use URLSession-provided resume data when available in the current session. Cancellation without resume data offers a fresh retry. Resume data is never fabricated or persisted with credentials. Size and SHA-256 are verified **before** package decoding. Cancellation remains available through verification/review preparation; the UI switches to Installing when the atomic commit begins. Identity/revision and existing package validation precede Library-v3 atomic install. Removed ideas retain explicit review/acknowledgement. Temporary files are removed after success/failure. A bad download never mutates the installed library.

Reviewer release gate: publish approved assets, configure catalog/API URLs and secrets, then run actual-network browse → download → integrity → install → offload → redownload and interruption/resume smoke tests. This branch does not publish releases or deploy services.
