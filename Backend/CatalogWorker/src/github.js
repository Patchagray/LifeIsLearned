export const REPO = 'Patchagray/LifeIsLearned-Published';
const API = 'https://api.github.com';
export class Unavailable extends Error {}
const require = (ok) => { if (!ok) throw new Unavailable(); };
export async function bounded(response, limit) {
  require(response.ok && Number(response.headers.get('content-length') || 0) <= limit);
  const reader = response.body?.getReader(); require(reader);
  const parts = []; let size = 0;
  try {
    while (true) { const {value, done} = await reader.read(); if (done) break; size += value.byteLength; require(size <= limit); parts.push(value); }
  } finally { await reader.cancel(); }
  const output = new Uint8Array(size); let offset = 0;
  for (const part of parts) { output.set(part, offset); offset += part.length; }
  return output;
}
export async function digest(data) { return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', data)), b => b.toString(16).padStart(2,'0')).join(''); }
const b64 = (data) => btoa(String.fromCharCode(...data)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const utf8 = new TextEncoder();
// GitHub provides PKCS#1 RSA PEM. WebCrypto imports PKCS#8; wrap without exposing it.
function length(n) { if (n < 128) return [n]; const bytes=[]; while(n) { bytes.unshift(n & 255); n >>= 8; } return [128+bytes.length,...bytes]; }
function tlv(tag, data) { return [tag,...length(data.length),...data]; }
function keyBytes(pem) {
  let bytes=Array.from(atob(pem.replace(/-----[^-]+-----|\s/g,'')),c=>c.charCodeAt(0));
  if (pem.includes('BEGIN RSA PRIVATE KEY')) bytes=tlv(48,[2,1,0,48,13,6,9,42,134,72,134,247,13,1,1,1,5,0,...tlv(4,bytes)]);
  return Uint8Array.from(bytes);
}
export async function appJWT(env) {
  require(/^\d+$/.test(env.GITHUB_APP_ID || '') && env.GITHUB_APP_PRIVATE_KEY);
  const now=Math.floor(Date.now()/1000);
  const head=b64(utf8.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
  const body=b64(utf8.encode(JSON.stringify({iat:now-60,exp:now+540,iss:env.GITHUB_APP_ID})));
  const key=await crypto.subtle.importKey('pkcs8',keyBytes(env.GITHUB_APP_PRIVATE_KEY),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,utf8.encode(head+'.'+body));
  return head+'.'+body+'.'+b64(new Uint8Array(signature));
}
const tokens = new WeakMap();
export class GitHub {
  constructor(env, fetcher=fetch) { this.env=env; this.fetcher=fetcher; }
  async token() {
    let saved=tokens.get(this.env);
    if (saved && saved.until > Date.now()+60000) return saved.value;
    require(/^\d+$/.test(this.env.GITHUB_INSTALLATION_ID || ''));
    const jwt=await appJWT(this.env);
    const response=await this.fetcher(`${API}/app/installations/${this.env.GITHUB_INSTALLATION_ID}/access_tokens`,{
      method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),
      headers:{'Content-Type':'application/json',Authorization:`Bearer ${jwt}`,Accept:'application/vnd.github+json','User-Agent':'LifeIsLearned-Catalog','X-GitHub-Api-Version':'2022-11-28'},
      body:JSON.stringify({repositories:['LifeIsLearned-Published'],permissions:{contents:'read'}})});
    const data=JSON.parse(new TextDecoder().decode(await bounded(response,32768)));
    require(typeof data.token==='string' && Date.parse(data.expires_at)>Date.now());
    tokens.set(this.env,{value:data.token,until:Date.parse(data.expires_at)}); return data.token;
  }
  async request(path, accept='application/vnd.github+json', extra={}) {
    const response=await this.fetcher(API+path,{redirect:'manual',signal:AbortSignal.timeout(20000),headers:{
      Authorization:`Bearer ${await this.token()}`,Accept:accept,'User-Agent':'LifeIsLearned-Catalog','X-GitHub-Api-Version':'2022-11-28',...extra}});
    if ([401,403].includes(response.status)) tokens.delete(this.env);
    return response;
  }
  async json(path) { return JSON.parse(new TextDecoder().decode(await bounded(await this.request(path),2*1024*1024))); }
  async file(path, ref, limit=2*1024*1024) {
    require(/^(catalog|approvals|covers)\/[a-zA-Z0-9._/-]+$/.test(path) && !path.split('/').some(x=>x==='..'||x==='.') && /^[a-f0-9]{40}$/.test(ref));
    const response=await this.request(`/repos/${REPO}/contents/${path}?ref=${ref}`,'application/vnd.github.raw+json');
    return bounded(response,limit);
  }
  async stream(assetID) {
    let response=await this.request(`/repos/${REPO}/releases/assets/${assetID}`,'application/octet-stream');
    // Always restart from zero: do not forward Range/If-Range or synthesize 206.
    for(let redirects=0; [301,302,303,307,308].includes(response.status); redirects++) {
      require(redirects<3); const url=new URL(response.headers.get('location'));
      require(url.protocol==='https:' && !url.username && !url.password && !url.port &&
        ['release-assets.githubusercontent.com','objects.githubusercontent.com'].includes(url.hostname));
      await response.body?.cancel();
      response=await this.fetcher(url.href,{redirect:'manual',signal:AbortSignal.timeout(60000),headers:{Accept:'application/octet-stream'}});
    }
    require(response.status===200); return response;
  }
}
