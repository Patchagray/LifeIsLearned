# Life Is Learned public library

This repository distributes approved learning collections. It contains only public discovery metadata, catalog checksums, and this publication guide. Prepared book JSON files and optional cover thumbnails are versioned GitHub Release assets. Presence in the catalog does not mean a book is ready: `planned` means Coming soon, `unavailable` means Request, and only `available` includes a package download.

Catalog: https://raw.githubusercontent.com/Patchagray/LifeIsLearned-Catalog/main/catalog.json

No GitHub account is needed in the app. Browsing fetches metadata and optional small cover thumbnails. Whole books download only when you choose Download/Restore/Update. Installed reading and packaged narration work offline. Library progress, Idea Cards and history stay on the device when a book is offloaded.

## Public asset boundary

Every published JSON, including its embedded illustrations and MP3 narration, can be downloaded and extracted by anyone. This is public distribution, with no DRM or concealment of the contents. Each book requires the owner's explicit publication and rights approval, including illustration and narration redistribution. No research dossiers, production prompts/scripts, voice configuration, raw audio masters, drafts, credentials, personal data or internal reports belong here. No blanket redistribution license is inferred by publication.

## Publication procedure

1. Finalize the reviewed format-2 whole-book JSON in the production workspace. Keep the approved Catalog 001 ID. Assign a higher collection revision for every changed release; semantic lesson changes also require idea revision increases.
2. Validate package structure, illustrations, planning/release timing, and any packaged narration with the production validation tools. Structural validation alone is not editorial or rights approval.
3. Review the exact release manifest (book ID, collection revision, SHA-256, byte count and optional thumbnail). Obtain explicit owner approval for those bytes and their public redistribution. Keep approval and internal QA records outside this repository.
4. Use a unique release tag `<bookID>-r<revision>` and a single `<bookID>-r<revision>.json` asset. Enable GitHub immutable releases in repository Settings before publication. Create a draft release, attach the approved files, then publish. Never clobber or replace an existing revision.
5. Verify the anonymous HTTPS release download against the approved SHA-256 and exact size. Copy that metadata into `catalog.json`, mark that book `available`, and update its and the catalog's UTC `updatedAt`. Keep all other titles honest about readiness. Optional thumbnails must be separately approved PNG/JPEG, at most 512 KiB and 2048×2048.
6. Validate catalog schema 1 / Catalog 001 revision 1, canonical IDs/order/eight shelves/tags, HTTPS distribution URLs, status consistency, monotonic package revisions and ≤2 MiB metadata size. Recompute `checksums.json` from the exact catalog bytes. Review the diff and commit only the three allowlisted repository files.
7. Push the catalog update. Verify unauthenticated catalog parsing and an app download → checksum → install → offline playback → offload → restore pass. A failed release/upload must not advertise a book as available. A failed metadata fetch must not replace the app's last good cache.

The production helper supports review preparation separately from publication; no automatic release job is installed here. The reader app contains no GitHub write credential.

## Transport and limits

The app permits HTTPS catalog/assets in this repository, with GitHub release CDN redirects. It sends no token, uses bounded requests and conditional catalog refreshes (ETag), and retains a last good offline cache. Files use formatVersion 2 and are independent of GitHub as a transport.

GitHub [release assets must each be under 2 GiB](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases); this app's stricter JSON limit is **64 MiB**, including base64 media. The [REST API unauthenticated limit is 60 requests per hour per originating IP](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api), with additional abuse/secondary limits possible. The app uses direct catalog/release URLs rather than polling the REST API. Those links still depend on GitHub availability and service policies; unlimited distribution is not guaranteed. See [immutable release guidance](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
