import approvedIDs from './catalog-ids.json' with { type: 'json' };
const approved = new Set(approvedIDs);
const encoder = new TextEncoder();
const json = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...headers }
});
export const normalize = value => value.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
export function validISBN(value) {
  return /^97[89][0-9]{10}$/.test(value) && [...value].reduce((sum, n, i) => sum + Number(n) * (i % 2 ? 3 : 1), 0) % 10 === 0;
}
export function validate(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('Invalid metadata');
  const allowed = new Set(['catalogBookID', 'title', 'author', 'isbn13', 'source']);
  if (Object.keys(input).some(key => !allowed.has(key))) throw new Error('Only reviewed book metadata is accepted');
  const clean = (value, max, optional = false) => {
    if (optional && (value == null || value === '')) return null;
    if (typeof value !== 'string' || !value.trim() || value.length > max || /[\x00-\x1f]/.test(value)) throw new Error('Invalid metadata field');
    return value.trim();
  };
  const title = clean(input.title, 300), author = clean(input.author, 200, true);
  const catalogBookID = clean(input.catalogBookID, 100, true);
  if (catalogBookID && !approved.has(catalogBookID)) throw new Error('Unknown catalog identity');
  const isbn13 = clean(input.isbn13, 24, true)?.replace(/[ -]/g, '') || null;
  if (isbn13 && !validISBN(isbn13)) throw new Error('Invalid ISBN-13');
  if (!['scanner', 'library'].includes(input.source)) throw new Error('Invalid request source');
  if (!normalize(title)) throw new Error('A title is required');
  return { title, author, catalogBookID, isbn13, source: input.source };
}
async function digest(value) {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))].map(n => n.toString(16).padStart(2, '0')).join('');
}
async function readBody(request) {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) throw new Error('Expected JSON');
  if (Number(request.headers.get('content-length')) > 2048) throw new Error('Metadata too large');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('Metadata required');
  const parts = []; let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read(); if (done) break;
      size += value.byteLength;
      if (size > 2048) throw new Error('Metadata too large');
      parts.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const part of parts) { bytes.set(part, offset); offset += part.byteLength; }
  return validate(JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)));
}
async function rateAllowed(request, env, now) {
  // Cloudflare supplies this header at its edge. Never trust arbitrary forwarded IP headers.
  const ip = request.headers.get('CF-Connecting-IP');
  if (!ip || !env.RATE_LIMIT_SALT) return false;
  const minute = Math.floor(now / 60000);
  const key = await crypto.subtle.importKey('raw', encoder.encode(env.RATE_LIMIT_SALT), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signed = await crypto.subtle.sign('HMAC', key, encoder.encode(`${minute}|${ip}`));
  const bucket = [...new Uint8Array(signed)].map(n => n.toString(16).padStart(2, '0')).join('');
  const row = await env.DB.prepare(`INSERT INTO request_rate_limits(bucket_key,hits,expires_at) VALUES (?,1,?)
    ON CONFLICT(bucket_key) DO UPDATE SET hits=hits+1 RETURNING hits`).bind(bucket, Math.floor(now / 1000) + 120).first();
  await env.DB.prepare('DELETE FROM request_rate_limits WHERE expires_at < ?').bind(Math.floor(now / 1000)).run();
  return row.hits <= 10;
}
export async function record(db, value, now) {
  const aliases = [`title:${normalize(value.title)}|${normalize(value.author || '')}`];
  if (value.isbn13) aliases.push(`isbn:${value.isbn13}`);
  if (value.catalogBookID) aliases.push(`catalog:${value.catalogBookID}`);
  // Unique aliases plus an atomic batch handle concurrent identical requests.
  // Retry if another request creates an alias after our initial read.
  for (let attempt = 0; attempt < 3; attempt++) {
    const rows = await db.prepare(`SELECT DISTINCT request_key FROM request_aliases WHERE alias IN (${aliases.map(() => '?').join(',')}) ORDER BY request_key`).bind(...aliases).all();
    const keys = rows.results.map(row => row.request_key);
    const key = keys[0] || await digest(aliases[0]);
    const timestamp = new Date(now).toISOString();
    const statements = [db.prepare(`INSERT INTO book_requests(request_key,title,author,isbn13,catalog_book_id,request_count,first_requested_at,last_requested_at)
      VALUES (?,?,?,?,?,0,?,?) ON CONFLICT(request_key) DO NOTHING`).bind(key, value.title, value.author, value.isbn13, value.catalogBookID, timestamp, timestamp)];
    for (const other of keys.slice(1)) {
      statements.push(db.prepare(`UPDATE book_requests SET request_count=request_count+COALESCE((SELECT request_count FROM book_requests WHERE request_key=?),0),
        first_requested_at=MIN(first_requested_at,COALESCE((SELECT first_requested_at FROM book_requests WHERE request_key=?),first_requested_at)) WHERE request_key=?`).bind(other, other, key));
      statements.push(db.prepare('UPDATE request_aliases SET request_key=? WHERE request_key=?').bind(key, other));
      statements.push(db.prepare('DELETE FROM book_requests WHERE request_key=?').bind(other));
    }
    for (const alias of aliases) {
      // Existing aliases to this record are fine. A conflicting owner aborts the batch.
      statements.push(db.prepare(`INSERT INTO request_aliases(alias,request_key) SELECT ?,? WHERE NOT EXISTS (SELECT 1 FROM request_aliases WHERE alias=? AND request_key=?)`).bind(alias, key, alias, key));
    }
    statements.push(db.prepare(`UPDATE book_requests SET request_count=request_count+1,last_requested_at=MAX(last_requested_at,?),
      isbn13=COALESCE(isbn13,?),catalog_book_id=COALESCE(catalog_book_id,?) WHERE request_key=?`).bind(timestamp, value.isbn13, value.catalogBookID, key));
    try {
      await db.batch(statements);
      const row = await db.prepare('SELECT request_count FROM book_requests WHERE request_key=?').bind(key).first();
      return { status: 'accepted', requestKey: key, requestCount: row.request_count };
    } catch (error) { if (attempt === 2) throw error; }
  }
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol !== 'https:') return json({ error: 'HTTPS required' }, 400);
    if (url.pathname !== '/v1/book-requests') return json({ error: 'Not found' }, 404);
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405, { Allow: 'POST' });
    if (!env.DB || !env.RATE_LIMIT_SALT) return json({ error: 'Requests are not configured' }, 503);
    let value;
    try { value = await readBody(request); } catch { return json({ error: 'Invalid book metadata (maximum 2048 bytes)' }, 400); }
    try {
      if (!await rateAllowed(request, env, Date.now())) return json({ error: 'Please try again later' }, 429, { 'Retry-After': '60' });
      return json(await record(env.DB, value, Date.now()));
    } catch { return json({ error: 'Request could not be confirmed' }, 503); }
  }
};
