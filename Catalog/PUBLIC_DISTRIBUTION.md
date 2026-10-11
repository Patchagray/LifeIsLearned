# Superseded by Handoff 006B

This public-repository procedure is historical and must not be executed. `Tools/publish_distribution.py publish` now refuses publication. Use [private publication gates](../ReleaseGate/README.md) and [Cloudflare operations](../Backend/CatalogWorker/README.md). No public distribution repository was created.

# Handoff 006 public distribution operations

The app source and public package distribution are separate repositories. H006 does not change visibility of any existing repository. The proposed distribution repository is `Patchagray/LifeIsLearned-Catalog`. The reviewed local scaffold is `Distribution/`; it currently contains metadata for 50 planned titles, with no downloadable book assets.

## Create only after owner approval

Copy just `Distribution/README.md`, `catalog.json` and `checksums.json` into a new standalone directory (not the source repository's `.git`). Validate it with:

```sh
python3 Tools/distribution_catalog.py /path/to/LifeIsLearned-Catalog/catalog.json --audit-directory /path/to/LifeIsLearned-Catalog
```

Initialize that directory with branch `main`, inspect and commit the three files, then use the authorized GitHub CLI session:

```sh
gh repo create Patchagray/LifeIsLearned-Catalog --public --source /path/to/LifeIsLearned-Catalog --remote origin --push
```

Never run this against the application or book-production working copy. Enable **Settings → General → Releases → Release immutability** before publishing book releases. No GitHub credential is put into the app or catalog.

## Prepare a concrete release review

```sh
python3 Tools/publish_distribution.py prepare /path/to/final-reviewed-book.json --output LocalVerification/Handoff006/release-review/BOOK-REVISION
```

This validates the existing authoring/planning contract and any supplied audio, copies the exact final file without rewriting it, and writes an internal `release-manifest.json` with ID, revision, SHA-256, size, and embedded asset counts. It refuses an existing output directory. It does not certify factual accuracy, licensing or physical voice quality. A book without packaged narration remains valid and uses device fallback; its existing premium-voice timing release policy still applies.

Owner approval must name these exact bytes, including public redistribution of embedded artwork/audio and completion of the release QA. An approval JSON stays under ignored `LocalVerification/` and has this shape (replace every example with the actual reviewed values):

```json
{
  "repository": "Patchagray/LifeIsLearned-Catalog",
  "publicRepositoryApproved": true,
  "books": [{
    "id": "APPROVED-STABLE-ID",
    "collectionRevision": 1,
    "sha256": "EXACT-64-HEX-DIGEST",
    "bytes": 123,
    "publicRedistributionApproved": true,
    "rightsIncludingImagesAndNarrationConfirmed": true,
    "releaseQAApproved": true
  }]
}
```

An agent must never invent approval values. Create this only from the owner's explicit approval, preserving the accompanying review record privately.

## Publish approved bytes and update metadata

```sh
python3 Tools/publish_distribution.py publish LocalVerification/Handoff006/release-review/BOOK-REVISION --approval LocalVerification/Handoff006/publication-approval.json --public-directory /path/to/LifeIsLearned-Catalog
```

The helper requires exact-byte approval, a clean allowlisted public worktree, matching remote, public visibility and enabled immutable releases. It refuses an existing release, stages a draft, uploads the one approved book JSON, publishes, then verifies the anonymous download size/hash. Only then does it update local catalog/checksum files. Review that diff, validate against the previous committed catalog, commit and push explicitly. It does not publish a catalog on a failed upload or verification. If a release upload/publication succeeds but a later step fails, inspect the existing release; never overwrite/delete it to retry. Confirm bytes manually and resume the catalog update after review.

The final JSON is publicly extractable. Raw narration masters, production scripts, voice configuration, research, credentials and internal reports stay out of the distribution repository. Optional approved cover thumbnails can be added through the existing `remote_catalog_metadata.py` helper; validate them and include them in the asset approval before upload.

## Runtime configuration and checks

`RemoteConfiguration` ships one read-only public catalog URL: `https://raw.githubusercontent.com/Patchagray/LifeIsLearned-Catalog/main/catalog.json`. A build-setting override is accepted only in DEBUG, and must pass the same distribution-origin check. Request API configuration remains separate; H006 deploys no request backend.

Metadata requests use ETag/If-None-Match, a 25-second timeout, 2 MiB bound, strict origin/CDN rules and last-good caching. Package transfers retain the existing 60-second request timeout, explicit start, progress/cancel/resume, 64 MiB bound, SHA-256/size preflight, identity/revision checks, removed-idea review and atomic installation. No reader account/sign-in is required. Raw catalog metadata may change; same-revision package bytes must not.

Release smoke test after approval: anonymous catalog parse → browse without downloading a package → explicit download → integrity check → install → airplane-mode reading/audio → offload → restore. Physical background audio/lock-screen checks remain distinct from simulator tests. Publication and real-network book smoke tests are blocked until exact assets are approved.
