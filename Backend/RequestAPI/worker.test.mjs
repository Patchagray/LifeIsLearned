import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker, { validate, record, normalize } from './worker.mjs';
class D1Fixture {
  constructor() { this.db = new DatabaseSync(':memory:'); this.db.exec(readFileSync(new URL('./schema.sql', import.meta.url), 'utf8')); }
  prepare(sql) {
    const statement = this.db.prepare(sql); let args = [];
    const wrapper = { bind: (...values) => { args = values; return wrapper; },
      first: async () => statement.get(...args) || null, all: async () => ({ results: statement.all(...args) }),
      run: async () => statement.run(...args) };
    return wrapper;
  }
  async batch(statements) {
    this.db.exec('BEGIN');
    try { const values = []; for (const statement of statements) values.push(await statement.run()); this.db.exec('COMMIT'); return values; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
}
const body = { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman', isbn13: '9780141033570', source: 'scanner' };
function request(data = body, headers = {}) {
  return new Request('https://fixture.invalid/v1/book-requests', { method: 'POST', headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '192.0.2.10', ...headers }, body: JSON.stringify(data) });
}
test('metadata normalization and strict privacy/identity boundary', () => {
  assert.equal(normalize('  THINKING—Fast & Slów '), 'thinking fast slow');
  assert.equal(validate(body).isbn13, body.isbn13);
  for (const value of [{ ...body, frame: 'base64' }, { ...body, catalogBookID: 'changed-id' }, { ...body, isbn13: '9780141033571' }, { ...body, title: '' }]) assert.throws(() => validate(value));
});
test('same title/ISBN aliases dedupe; later alias bridge preserves counts and first time', async () => {
  const db = new D1Fixture();
  const first = await record(db, validate(body), 1000);
  const second = await record(db, validate({ ...body, title: 'THINKING FAST AND SLOW', isbn13: null }), 2000);
  assert.equal(first.requestKey, second.requestKey); assert.equal(second.requestCount, 2);
  const third = await record(db, validate({ ...body, title: 'Another recognized title' }), 3000);
  assert.equal(third.requestKey, first.requestKey); assert.equal(third.requestCount, 3);
  const row = await db.prepare('SELECT * FROM book_requests').first();
  assert.equal(row.first_requested_at, new Date(1000).toISOString()); assert.equal(row.last_requested_at, new Date(3000).toISOString());
  await record(db, validate({ ...body, title: 'Separate title', isbn13: null }), 4000);
  const joined = await record(db, validate({ ...body, title: 'Separate title' }), 5000);
  assert.equal(joined.requestCount, 5);
  assert.equal((await db.prepare('SELECT * FROM book_requests').all()).results.length, 1);
});
test('HTTP success, duplicate, rate limit and no public admin queue', async () => {
  const env = { DB: new D1Fixture(), RATE_LIMIT_SALT: 'test-only-not-a-production-secret' };
  for (let i = 1; i <= 10; i++) { const response = await worker.fetch(request(), env); assert.equal(response.status, 200); assert.equal((await response.json()).requestCount, i); }
  assert.equal((await worker.fetch(request(), env)).status, 429);
  assert.equal((await env.DB.prepare('SELECT request_count FROM book_requests').first()).request_count, 10);
  assert.equal((await worker.fetch(new Request('https://fixture.invalid/admin'), env)).status, 404);
  const rate = await env.DB.prepare('SELECT bucket_key FROM request_rate_limits').first(); assert.equal(rate.bucket_key.length, 64); assert.ok(!rate.bucket_key.includes('192.0.2.10'));
});
test('size, method, unconfigured and DB failure fail closed', async () => {
  const env = { DB: new D1Fixture(), RATE_LIMIT_SALT: 'fixture' };
  assert.equal((await worker.fetch(request({ ...body, title: 'x'.repeat(3000) }), env)).status, 400);
  assert.equal((await worker.fetch(new Request('https://fixture.invalid/v1/book-requests'), env)).status, 405);
  assert.equal((await worker.fetch(request(), {})).status, 503);
  assert.equal((await worker.fetch(request(), { ...env, DB: { prepare() { throw new Error('offline'); } } })).status, 503);
});
