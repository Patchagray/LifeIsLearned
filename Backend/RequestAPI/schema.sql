CREATE TABLE IF NOT EXISTS book_requests (
  request_key TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT,
  isbn13 TEXT,
  catalog_book_id TEXT,
  request_count INTEGER NOT NULL DEFAULT 0,
  first_requested_at TEXT NOT NULL,
  last_requested_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS request_aliases (
  alias TEXT PRIMARY KEY,
  request_key TEXT NOT NULL REFERENCES book_requests(request_key)
);
CREATE TABLE IF NOT EXISTS request_rate_limits (
  bucket_key TEXT PRIMARY KEY,
  hits INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS request_priority ON book_requests(request_count DESC, last_requested_at DESC);
CREATE INDEX IF NOT EXISTS rate_expiry ON request_rate_limits(expires_at);
