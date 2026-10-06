# Life Is Learned — Catalog 001

This is the editorial source of truth for the first 50-book catalog. It is separate from the app's existing `CollectionCatalog`, which tracks installed lesson packages and learner revision state.

## Rules

- 50 unique books across 8 shelves.
- Exactly one primary shelf per book.
- Secondary shelves and granular tags are allowed.
- Stable book IDs become immutable once this patch is accepted.
- Authored content remains whole-book / whole-collection.
- Catalog presence does not imply a downloadable package exists yet.
- Handoff 004.5 adds no networking, download URLs, scanner, request flow, or new catalog UI.

## Shelf counts

1. Psychology & Human Behavior — 10
2. Communication & Negotiation — 7
3. Habits & Personal Growth — 8
4. Money & Personal Finance — 7
5. Leadership & Strategy — 7
6. Productivity & Focus — 4
7. Relationships & Emotional Intelligence — 3
8. Meaning, Philosophy & Resilience — 4

## Existing authored titles

- `influential-mind` — established stable ID.
- `never-split-the-difference` — intended stable ID; Codex must reconcile it against the existing authored package before the manifest is frozen.

`authoringPriority` is a production queue, not a user-facing ranking of book quality.

## Future 005 use

Handoff 005 can derive a remote/discovery catalog from this identity manifest and add transport metadata such as package URL, checksum, byte size, package revision, and availability. Those transport fields do not belong in 004.5.

## Canonical manifest and validation

`Catalog-001.json` is the approved schema-1, revision-1 manifest, copied unchanged from `LifeIsLearned_Catalog_001.json` in the supplied Catalog 001 handoff. SHA-256: `d99728adaab648b645915348ccba2f3c7e3ce6d4cf7c802af584e4b8ea92d7e2`.

From the repository root, using Python 3 and its standard library:

```sh
python3 Tools/validate_catalog.py
python3 -m unittest discover -s Tools -p 'test_catalog.py' -v
```

The validator also accepts a path to a proposed manifest. It is read-only, fails with exit code 1 and a specific field error, and prints a deterministic count summary on success. It checks schema/revision, required fields/types/rules, duplicate JSON keys, unique book/shelf identities, shelf references/order/distribution, secondary classifications, author/tag lists, catalog order, and the 1–50 authoring queue. Schema 1 has the supplied fields and status values; unknown fields, including transport metadata, require an explicit schema decision. A future approved expansion must update the catalog revision and the corresponding validation contract.

Validation establishes structural consistency. It does not review bibliographic facts, approve lesson content, verify narration timing, or prove package availability. The manifest is an editorial file and is not bundled into the app or connected to `CollectionCatalog` in this patch.

## Authored-ID reconciliation

The locally supplied `Never_Split_the_Difference_LifeIsLearned_Official.zip` contains `Never_Split_the_Difference_LifeIsLearned/Never_Split_the_Difference_LifeIsLearned_v2.json`. Its existing `book.id` is **`never-split-the-difference`**, matching this manifest; no ID change was needed. Package identity inspected: format 2, collection revision 1, 10 ideas. JSON SHA-256: `e8679c91da42f3e709f1568d5cb91f7bb45038ff65b54e676e727cdd7c8ce928`.

The supplied Influential Mind package also uses **`influential-mind`** (format 2, collection revision 2, 10 ideas), matching the established app/catalog identity. Package inspection here was limited to identity and metadata; the authored archives were not imported or republished as part of this foundation.

## Before authoring a Catalog 001 book

Look up the title in `Catalog-001.json` and copy its exact `id` into the package's `book.id` before creating lesson IDs, progress, or cards. Keep that ID through every later package revision. Do not derive a fresh slug from the title or use authoring priority as identity. Keep the approved shelf/tag assignments separate from the lesson-package format.

Use the existing complete format-2 collection contract, 1–12 selected ideas, and the ≤300-second complete reference experience gate. Adding a title outside Catalog 001 requires a separately approved later catalog revision. Catalog metadata is not evidence that the source book or any lesson content has been reviewed. See `../CONTENT_AUTHORING.md` and the root `LifeIsLearned_Handoff_004_5_Catalog_Foundation.md`.
