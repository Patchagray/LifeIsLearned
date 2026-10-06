# Life Is Learned — Handoff 004.5
## Catalog 001 Foundation

**Date:** 2026-10-05  
**Repository:** `Patchagray/LifeIsLearned`  
**Target baseline:** accepted result of `feature/handoff-004-idea-collection`  
**Scope:** catalog identity + validation only.

## Decision

Apply this small foundation patch **after 004 is accepted and before additional Catalog 001 books are authored**. Do not wait for 005.

The sequence should be:

`Catalog 001 identity → authored whole-book packages → Handoff 005 remote discovery/distribution`

This prevents new authored packages from inventing book IDs and taxonomy independently, while keeping remote-library work out of the current patch.

## Architecture boundary

The app already has `CollectionCatalog` for installed packages and revision history. Do not repurpose it.

Use a separate editorial/discovery concept, for example:

- `Catalog/Catalog-001.json`
- optional Swift type: `EditorialCatalogManifest` or `DiscoveryCatalogManifest`
- `Tools/validate_catalog.py`

Avoid a generic `Catalog` type if it makes the existing `CollectionCatalog` ambiguous.

## Canonical input

Use the accompanying `LifeIsLearned_Catalog_001.json` as the approved starting manifest. It contains 50 books, 8 shelves, primary/secondary shelf assignments, tags, stable IDs, package/editorial status, and authoring priority 1–50.

Required primary shelf counts are **10 / 7 / 8 / 7 / 7 / 4 / 3 / 4**, totaling 50.

## Existing authored IDs

**The Influential Mind:** `influential-mind` is established. Do not rename it.

**Never Split the Difference:** the draft manifest proposes `never-split-the-difference`. Before freezing the manifest, inspect the already-authored package if available. If its existing `book.id` differs, preserve that package ID and update the catalog entry once. Do not rename established content merely to make the slug match. Record the reconciliation result.

## Required work

1. Add the manifest and README under `Catalog/`.
2. Add a deterministic validator, preferably `Tools/validate_catalog.py`.
3. Validate schema/revision, declared count, exactly 50 books, unique nonempty IDs, valid shelf references, unique shelf order, no primary shelf repeated as secondary, nonempty de-duplicated tags, and authoring priorities exactly 1–50.
4. Add negative tests/fixtures for duplicate book ID, unknown shelf, duplicate priority, wrong count, and self-secondary classification.
5. Update authoring guidance so every future package for a Catalog 001 title reuses its exact catalog `book.id`.
6. Keep this static/editorial unless a runtime type has a concrete immediate purpose.
7. Preserve the manual whole-book import contract.
8. Do not change lesson IDs/revisions, progress keys, idea-card identity, narration, or Handoff 004 behavior.

## Authoring contract after acceptance

For a Catalog 001 book, look up and reuse the exact stable book ID before authoring. Continue using the formatVersion-2 whole-collection package contract, 1–12 selected ideas, and the ≤300-second reference first-pass idea gate.

Do not silently add books outside Catalog 001 during authoring; that requires a later catalog revision.

## Explicit non-goals

This is **not 005**. Do not implement GitHub Releases integration, package URLs/checksums, remote refresh, download queues, camera scanning/OCR, ISBN lookup, “Request this book,” editorial backend, accounts/sync, Dive Deeper, or new catalog UI.

## Acceptance evidence

Return branch + exact commit, files changed, validator/test commands and results, the reconciled Never Split ID, confirmation of 50 books/8 shelves/exact shelf counts, and confirmation existing import/004 tests still pass. Do not merge automatically.

## Next

After acceptance, Catalog 001 is the identity source of truth. New books can be authored in `authoringPriority` order without waiting for 005. Handoff 005 will later consume this foundation for remote discovery, downloads, scanning/search, and request routing.
