# Life Is Learned — PRIVATE Published Book Repository

This repo is the private distribution origin for Life Is Learned. It is **not** the production/source repo, a book factory, or an app backend. Only the Cloudflare Worker (read-only GitHub App) and owner-approved release workflow should access published packages.

**Initial state: zero published books.** `catalog/Remote-Catalog-001.json` is copied verbatim from the app repository by the bootstrap script and lists the 50 catalog titles as planned. An empty `approved-packages.json` means every book is coming soon. An independently approved cover preview can be displayed before a package is approved. Creating the repo does not approve any book.

To publish later: technical audio gate PASS for every idea + verified ElevenLabs provenance + explicit owner approval for exact SHA-256/revision + immutable release asset verified + allowlist updated LAST. No partial books, no fallback-only audio, no raw MP3 masters or production prompts.

Private GitHub origin does not mean Cloudflare downloads are app-only. Until App Attest/authentication exists, anyone who knows a Worker download URL can request an approved package.
