# Private catalog Worker — Handoff 006B

The Worker returns the canonical 50-title catalog, separately approved previews, and exact approved package streams. Its GitHub origin is pinned to `Patchagray/LifeIsLearned-Published`. Without origin authentication, catalog metadata has only planned titles and `X-Library-State: planned-only`; asset routes fail closed. The app preserves its last good cache and reports the refresh failure.

## Staging setup

1. Cloudflare Wrangler authorization is complete for the current local user. Re-run `wrangler login` only if `wrangler whoami` no longer shows the staging account.
2. The existing App is at **Settings → Developer settings → GitHub Apps → Life Is Learned Published Reader**. If rebuilding it, use account-only installation, disable webhooks, grant **Repository permissions → Contents: Read-only**, and keep the App private to the Patchagray account. Metadata read is mandatory in GitHub. The matching non-secret manifest is included here.
3. The App is installed on **Patchagray → Only select repositories → LifeIsLearned-Published**. Its current installation ID is stored in a Worker Secret; do not broaden repository access. The private key remains in local ignored storage and a Worker Secret.
4. The current installation is provisioned with all three secrets. For future rotation/recovery, from this directory use secure prompts/local redirection:

```sh
wrangler secret put GITHUB_APP_ID --env staging
wrangler secret put GITHUB_INSTALLATION_ID --env staging
wrangler secret put GITHUB_APP_PRIVATE_KEY --env staging < /private/local/path/to/downloaded-key.pem
wrangler secret list --env staging
npm test
wrangler deploy --dry-run --env staging
wrangler deploy --env staging
```

Never paste credentials into chat, source, build settings or logs. The Worker accepts RSA PKCS#1 or PKCS#8 PEM, signs a nine-minute JWT and requests a token scoped to this one repository with Contents read. It caches tokens in isolate memory until shortly before expiry and clears them on upstream 401/403. No PAT fallback is provisioned.

H006B authorizes staging; production remains reviewer controlled. Default Wrangler settings disable workers.dev/previews. The explicit staging environment enables its endpoint. The rate limiter allows 60 requests/minute per Cloudflare-observed IP at the location; it discourages spam, not proof of identity. Missing/failed limiter bindings fail closed.

## Routes and integrity

- `GET /v1/catalog`: schema 1/catalog-001 revision 1; 50 planned titles plus approved overlays; ETag/304. No arbitrary queries, paths or asset IDs.
- `GET /v1/covers/{bookID}`: approved PNG/JPEG <=512 KiB with exact hash/size. The app also performs native image decoding and dimension checks, and caches by hash. Preview approval never enables downloads.
- `GET /v1/books/{bookID}/download`: approved immutable release metadata and exact byte stream. The app verifies full SHA, size, identity, revision and package before atomic installation.
- `GET /healthz`: generic process health, no inventory or credentials.

Every request confirms origin privacy and pins metadata/approval/cover reads to one main commit. No cached approved overlay survives authentication/validation failure. The planned JSON must match the bundled canonical catalog in JSON meaning. Missing/deleted assets, mismatched digests, mutable releases and malformed approvals fail closed. A new metadata contract requires reviewed deployment. See `../../ReleaseGate/README.md` for schemas and publication order.

GitHub asset downloads may return 200 or a signed 302. At most three HTTPS release-CDN redirects are followed server-side, with no Authorization or client Range headers on the CDN request. No private URL, redirect Location or credential reaches the app. The Worker checks Content-Length, strips upstream headers and counts streamed bytes without buffering a package. GitHub's stored digest is corroborated against the approval; the client remains the final whole-file SHA verifier.

This version returns a full **200**, `Accept-Ranges: none`, even for Range requests. URLSession restarts from byte zero; no partial response is invented. Tests cover clean restart, stream cancellation, redirect safety and truncated lengths. Cancel/retry remains available.

## Operations

Upstream metadata/token timeouts are 15–20 seconds; asset transfer has a 60-second deadline. Generic errors expose no exception text, private paths or secrets. GitHub 401/403/404/429/5xx produces planned-only metadata or 503 asset responses. Registries are read afresh each request; new main commits take effect immediately, and public ETags reflect client metadata. No CDN package cache is populated. Client-owned installed copies remain usable offline after server revocation.

An empty registry takes five upstream reads; each approved artifact adds approval/release validation reads. Before scaling to a full catalog, evaluate account subrequest limits and add reviewed batching/caching. Paid services must not be enabled silently. To rotate a key, generate a replacement GitHub App key, replace the Worker Secret, redeploy/verify staging, then revoke the old key. Revoked/unavailable credentials fail closed.

Anyone with a Worker URL can request a later approved asset. Private GitHub prevents anonymous origin access; this service supplies no app-only authorization, App Attest or DRM.

References: [installation tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app), [release assets](https://docs.github.com/en/rest/releases/assets), [Worker Secrets](https://developers.cloudflare.com/workers/configuration/secrets/), [Worker limits](https://developers.cloudflare.com/workers/platform/limits/).

Toolchain: Wrangler 4.80.0; compatibility date 2026-04-08 matches its bundled runtime. The packet’s newer suggested date prevented local runtime startup; no requested API depends on that newer date. This is pinned explicitly for reproducible local/staging behavior.
