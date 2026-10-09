# LIFE IS LEARNED — HANDOFF 006
## Explore Catalog + Public GitHub Distribution

**Status:** Codex implementation order | **Date:** 2026-10-09

## Mission

Implement an in-place Your Library / Explore experience backed by a separate public GitHub distribution repository. Keep the private production repository, scripts, masters, voice configuration, and unpublished assets private. Deliver a usable catalog-to-download-to-offline-reading flow.

## Baseline and branch

Start from feature/handoff-005-library-platform at verified head 19c73333ac3d0fdf26541de2096c2452c0c01c33 (2026-10-08). Confirm head and inspect current implementation before editing; do not overwrite newer work. Create feature/handoff-006-explore-distribution. Preserve 005 audio, offload, collection/history, scanner, Dive Deeper, recovery and import behavior.

## 006A — In-place navigation

In LibraryView, keep the existing home hero/Continue Learning and Ideas/Settings actions. In the library section, place an accessible two-state segmented selector: Your Library | Explore, directly in the Your Library heading area, responsive to iPad and iPhone. Your Library shows local installed/offloaded titles, count, search, and existing shelf/grid presentation. Explore replaces that section's content in place with the remote discovery catalog and shelves. Do NOT push a separate DiscoveryView for normal Explore. Preserve scroll position where practical and avoid an unexpected navigation reset. Switching states must not stop ongoing narration or discard learner state. The toggle must be visible even if no books are installed. Search placeholder and result count must follow active mode; do not blend local and remote results.

## 006B — Plus menu and restoration

Remove Browse Library from the plus confirmation dialog entirely. Keep Scan a Book and Import File (and Cancel). Scanner catalog matches and offloaded remote-book Restore should navigate to Explore, focused on the matching title, not an obsolete Browse Library route. Manually imported offloaded books continue to prompt for re-import. No new bottom navigation bar or redundant Browse Catalog menu item.

## 006C — Explore shelves and state

Use the canonical Catalog 001 book IDs and eight shelves; preserve order/primary and secondary shelf semantics. Display all 50 planned titles only if the discovery manifest includes them, with clear status: Available for download, Coming soon, Installed, Offloaded/Restore, Update available, Downloading, Failed. Never show an unbuilt title as downloadable. Explore includes metadata-only cover/author/description/tags/primary shelf, shelf browsing, search, and book details. Optional featured/recent shelves must be computed from real metadata; no invented popularity or ratings. Installed books should open normally; offloaded books should restore with retained progress, cards, favorites, and history.

## 006D — Distribution repository

Codex should create a NEW public GitHub repository, suggested name Patchagray/LifeIsLearned-Catalog, using an authorized GitHub CLI session or explicit user approval for public creation. Never change visibility of existing private repo. If GitHub permission/auth is missing, create the repository scaffold locally and report the exact blocked command; do not claim the remote repo was created. Only publish release-approved import-ready JSON packages, compact public catalog metadata, approved cover thumbnails, checksums and byte counts. Exclude research dossiers, prompts, authoring drafts, original production sheets, voice-generation scripts/config, raw MP3 masters, secrets, logs, personal data, and internal reports. IMPORTANT: packaged final JSON can contain embedded narration MP3 and illustrations. Public distribution makes those playable/extractable by anyone; this is an intentional exposure requiring owner approval. Do not imply the app can conceal the source or DRM-protect assets.

## 006E — Release/catalog contract

Prefer GitHub Releases immutable versioned package assets rather than raw main-branch blobs. Publish one asset per book/revision. Maintain a small versioned catalog.json with schemaVersion, catalogRevision, stable book ID, title, author, shelves, editorial status, optional thumbnail URL, package revision, package URL, SHA-256, exact byte count, and updatedAt. Validate HTTPS origins, allowlisted GitHub hosts, IDs, uniqueness, shelf references, status/URL consistency, revision monotonicity and size limits. Catalog should not contain production credentials or private repo URLs. Write README with exact publication SOP: finalize package -> validate -> approve public assets -> upload release -> hash/size -> update catalog -> verify downloads. Initial publication: use only the four books user says are ready after inspecting actual package files and securing explicit approval; do not infer their identities or publish unreviewed material.

## 006F — Download and storage

Reuse existing 005 discovery networking, integrity verification, cancellation/resume, staged import, atomic install, revision logic and offload preservation rather than rebuilding. Download only on explicit user action, except a metadata-only catalog refresh. Validate SHA-256 and byte size before import; reject missing assets, invalid package, mismatched book ID or downgrade. Surface progress, retry, cancel, network/offline/404/permission failures; handle CDN redirects safely. Offline installed reading and packaged MP3 must work without GitHub. Preserve learner progress and cards through update and offload. Never require GitHub sign-in in the reader app.

## 006G — Configuration and trust

Configure a default read-only public catalog endpoint shipped with the app; preserve a developer override only in debug/test if necessary. Keep all tokens out of the binary. Use HTTPS, appropriate caching/ETag behavior, timeouts, and actionable failure states. GitHub public API/release rate limits and asset-size constraints must be documented; no claims of guaranteed unlimited distribution. Do not accidentally leak the private production repository through app UI, analytics, source URLs, or metadata.

## 006H — QA and acceptance

Tests: empty local library still offers Explore; toggle stays in-place on iPhone/iPad; search/filter/count mode isolation; dynamic type/VoiceOver; plus menu has only Scan/Import; scanner success focuses Explore; remote offload restore preserves progress/history/cards; manual restore requests re-import; manifest contains planned vs available titles correctly; remote package integrity tampering rejected; download cancellation/retry/offline; no silent full-book downloads while browsing; no duplicate book identities; update is atomic; audio survives installation/offline and is reclaimed on offload; production materials absent from public repository; public catalog URL works unauthenticated. Provide simulator screenshots, test logs, diff, commit SHA, release manifest, and physical-device checklist. Never fabricate passing tests.

## Implementation sequence

1. Inspect 005 branch and document reused DiscoveryView, RemoteConfiguration, LibraryStore, source metadata, and download path. 2. Implement in-place Explore UI and scanner/restore routes. 3. Create distribution repo scaffold + validators + release publishing script. 4. Create public repo only with authorized credentials and explicit public-asset approval. 5. Connect app to real manifest and run QA. 6. Produce HANDOFF_006_IMPLEMENTATION_REPORT.md with evidence, outstanding risks, branch/commit and repo URL.

## Non-goals and constraints

Do not generate new books, audio or artwork. Do not redesign the reader or cards. Do not migrate to a hosted backend or add accounts. Do not make the private repo public. Do not require a catalog repo for offline library access. Do not reset progress on metadata/audio-only package updates. Treat this as a 006 integration on top of 005, not a replacement of its remote-download architecture.
