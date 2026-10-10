# Cloudflare Worker request/response contract — no implementation claim

**Server-side only:** GitHub App installation token with read-only access to private published repo. Store keys only as Cloudflare Worker Secrets.

- `GET /v1/catalog` returns exact `DiscoveryCatalog` schema 1 / catalog ID `catalog-001` / catalog revision 1. Start from the immutable `Remote-Catalog-001.json` 50-title metadata, overlay ONLY validated approved cover/package allowlists. All URLs are Cloudflare HTTPS; no GitHub/private metadata fields. Unapproved titles remain `planned` with no package.
- `GET /v1/covers/{canonicalBookID}` returns valid approved JPEG/PNG, <=512 KiB and content hash matching internal allowlist. `404` for unapproved preview.
- `GET /v1/books/{canonicalBookID}/download` returns only fully approved immutable private GitHub Release asset, exact byte stream. `404` if no package allowlist entry. No arbitrary file path/query/asset-ID access. Request Range handling must be tested; 200/full fallback acceptable only when client restarts cleanly.
- `GET /healthz` exposes no sensitive info.

### Response shape (one book example, fictional placeholders)

```json
{
  "schemaVersion": 1,
  "catalogID": "catalog-001",
  "catalogRevision": 1,
  "books": [
    {
      "id": "influential-mind",
      "title": "The Influential Mind",
      "authors": ["Tali Sharot"],
      "primaryShelfID": "psychology-human-behavior",
      "secondaryShelfIDs": ["communication-negotiation"],
      "tags": ["psychology", "human behavior"],
      "isbn13": [],
      "availability": "planned"
    }
  ]
}
```

At bootstrap, all 50 entries are planned. `thumbnail` may later be appended as `{url:"https://WORKER/v1/covers/ID",sha256:"...",bytes:12345}` after separate owner preview approval. `package` and `availability:"available"` may appear only after complete premium-audio gate + explicit owner approval + release publication. `package:{collectionRevision:3,url:"https://WORKER/v1/books/ID/download",sha256:"...",bytes:1234567}`. This example is illustrative only, not the complete 50-book catalog: copy the **real** canonical manifest in Codex.

### Security caveat
Without App Attest or user login, any client can call the Worker endpoint. The Worker conceals GitHub credentials/private repo paths from responses but does not deliver app-only authorization, DRM or copy prevention. Rate limit and fail closed.
