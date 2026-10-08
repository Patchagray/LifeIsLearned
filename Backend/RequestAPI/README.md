# Editorial request API — reference implementation, not deployed

The iOS client depends only on HTTPS JSON, not Cloudflare or GitHub credentials. `POST /v1/book-requests` accepts `catalogBookID?`, required `title`, `author?`, `isbn13?`, and `source` (`scanner` or `library`). It returns `{status:"accepted",requestKey,requestCount}`. UI sends only after explicit review and Request. No image, account identifier or camera frame field is accepted.

- Metadata is capped at 2,048 actual streamed bytes, title 300 characters, author 200, approved Catalog 001 IDs, valid ISBN-13.
- Normalized title/author, ISBN and catalog-ID aliases deduplicate requests; alias bridges combine existing counts. First/last dates are retained. Prepared statements and atomic D1 batches protect writes; conflicting concurrent alias insertion retries.
- Ten requests per minute per Cloudflare edge IP, represented only by a salted HMAC tied to that minute. Raw IP is never stored or logged here. Rate rows expire after two minutes and are cleaned on requests. Reviewer must provision `RATE_LIMIT_SALT`; no secret means 503, never an unprotected endpoint. Add edge-level bot protections if observed traffic warrants them.
- Counts represent submissions, not unique people or votes. No account is required. Device retries after an uncertain response can count again; the UI never automatically retries POST.
- No public admin endpoint. Editorial queue is a reviewer-authenticated database query:
  `SELECT title,author,isbn13,catalog_book_id,request_count,first_requested_at,last_requested_at FROM book_requests ORDER BY request_count DESC,last_requested_at DESC;`
- No request counts are published into the static discovery catalog.

## Tests (local only)

`node --test Backend/RequestAPI/worker.test.mjs` uses Node 24's in-memory SQLite adapter for the D1 prepared-statement/batch interface. It exercises real SQL constraints/transactions and HTTP behavior, not a deployed Worker. Platform integration remains a release smoke check.

## Reviewer-controlled deployment

Do not run these steps without authorization. Create a Cloudflare Worker and D1 database in the reviewer account; copy `wrangler.example.toml` to ignored `wrangler.toml`; supply the database ID and approved route. Apply `schema.sql` using the authenticated D1 tooling. Provision a random `RATE_LIMIT_SALT` using Worker secrets (never app configuration). Deploy only after review, and configure the app's `LIL_BOOK_REQUEST_API_URL` with the complete HTTPS `/v1/book-requests` endpoint. Keep `workers_dev=false` until an approved route is provisioned. No production resource is created by these source files.

Run real-network accepted/duplicate/429/failure checks and inspect the protected editorial query before release. Review retention and delete editorial data through authenticated database tooling as needed.

API implementation follows Cloudflare's documented [D1 prepared statements](https://developers.cloudflare.com/d1/worker-api/prepared-statements/) and [atomic batch API](https://developers.cloudflare.com/d1/worker-api/d1-database/). The catalog ID allowlist is copied exactly from Catalog 001; update only under an approved identity-contract revision.
