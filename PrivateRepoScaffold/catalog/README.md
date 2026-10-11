# Catalog publication registry

- `Remote-Catalog-001.json`: copied unchanged from app source `Catalog/Remote-Catalog-001.json` at bootstrap. Fifty planned metadata entries. Never mark a book available merely because a package file exists.
- `approved-packages.json`: strict allowlist, initially empty. Each future record: `{ "bookID": "canonical-id", "collectionRevision": 1, "releaseID": 100, "releaseAssetID": 1234, "bytes": 123456, "sha256": "64-lowercase-hex", "approvalRecord": "approvals/book-r1.json", "preflightReportRecord": "approvals/book-r1-preflight.json" }`. Only the release-approval process writes this file, and only after the owner has approved the exact hash and the uploaded asset is available.
- `approved-covers.json`: separate cover-preview allowlist, initially empty. Each future record: `{ "bookID": "canonical-id", "path": "covers/book-id.jpg", "bytes": 12345, "sha256": "64-lowercase-hex", "mediaType": "image/jpeg", "approvalRecord": "approvals/cover-preview.json" }`. Explicit image preview approval is required even when the full book is unfinished.

The Worker must overlay these registries on the 50 planned entries and expose only client-compatible `thumbnail` and `package` objects pointing to Worker URLs. Never pass `releaseAssetID`, private paths or approval records to the app. Fail closed if registries are malformed or mismatched.
