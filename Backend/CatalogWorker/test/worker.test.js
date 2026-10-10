import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {generateKeyPairSync, createVerify} from 'node:crypto';
import {canonical} from '../src/catalog.js';
import {createHandler} from '../src/index.js';
import {GitHub,REPO,appJWT,digest} from '../src/github.js';
const encoder=new TextEncoder(), bytes=(v)=>encoder.encode(JSON.stringify(v));
const id=canonical.books[0].id, ref='a'.repeat(40);
const env={RATE_LIMITER:{limit:async()=>({success:true})}};
function fixture() {
 const payload=encoder.encode('{"synthetic":"transport-only"}');
 const files={'catalog/Remote-Catalog-001.json':canonical,'catalog/approved-packages.json':{schemaVersion:1,entries:[]},'catalog/approved-covers.json':{schemaVersion:1,entries:[]}};
 const log=[];let release;
 const gh={json:async(path)=>{log.push(path);if(path===`/repos/${REPO}`)return {private:true,full_name:REPO};if(path.endsWith('/commits/main'))return {sha:ref};if(path.endsWith('/releases/1'))return release;throw Error('fixture');},
 file:async(path,commit)=>{log.push(path);assert.equal(commit,ref);if(!(path in files))throw Error('missing');return files[path] instanceof Uint8Array?files[path]:bytes(files[path]);},
 stream:async()=>new Response(payload,{headers:{'Content-Length':String(payload.length),'Location':'private-url','Authorization':'must-not-leak'}})};
 const handle=createHandler(()=>gh);
 async function approveBook() {
  const hash=await digest(payload);
  files['catalog/approved-packages.json'].entries=[{bookID:id,collectionRevision:1,releaseAssetID:2,releaseID:1,bytes:payload.length,sha256:hash,approvalRecord:'approvals/test-book.json',preflightReportRecord:'approvals/test-preflight.json'}];
  files['approvals/test-book.json']={type:'life-is-learned-book-release-approval-v1',approved:true,bookID:id,collectionRevision:1,packageBytes:payload.length,packageSHA256:hash,audioQAReportSHA256:'b'.repeat(64),preflightReportSHA256:'c'.repeat(64),technicalGate:'all-idea-elevenlabs-passed',approvedGuideVoiceID:'fixture-guide',approvedStorytellerVoiceID:'fixture-story',approvedBy:'test-only',approvalReference:'unit fixture, not actual approval',approvedAt:'2026-10-10T00:00:00Z'};
  files['approvals/test-preflight.json']={result:'passed',errors:[],validatorExitCodes:{authoring:0,audio:0},bookID:id,collectionRevision:1,packageSHA256:hash,packageBytes:payload.length,audioQAReportSHA256:'b'.repeat(64)};
  files['approvals/test-book.json'].preflightReportSHA256=await digest(bytes(files['approvals/test-preflight.json']));
  release={id:1,immutable:true,draft:false,assets:[{id:2,state:'uploaded',size:payload.length,digest:'sha256:'+hash}]};
 }
 async function approveCover() {
  const data=Uint8Array.from([137,80,78,71,13,10,26,10,...new Array(24).fill(0)]),hash=await digest(data);
  files['covers/test.png']=data;
  files['catalog/approved-covers.json'].entries=[{bookID:id,path:'covers/test.png',bytes:data.length,sha256:hash,mediaType:'image/png',approvalRecord:'approvals/test-cover.json'}];
  files['approvals/test-cover.json']={type:'life-is-learned-cover-preview-approval-v1',approved:true,bookID:id,bytes:data.length,sha256:hash,mediaType:'image/png',approvedBy:'test-only',approvalReference:'unit fixture',approvedAt:'2026-10-10T00:00:00Z'};
 }
 const request=(path,headers={},method='GET')=>handle(new Request('https://catalog.example'+path,{method,headers}),env);
 return {files,log,gh,handle,request,approveBook,approveCover,payload};
}
test('empty canonical catalog, conditional metadata and no payload transfer',async()=>{
 const f=fixture(),r=await f.request('/v1/catalog'),c=await r.json();assert.equal(c.books.length,50);assert.ok(c.books.every(b=>b.availability==='planned'&&!b.package&&!b.thumbnail));
 assert.equal((await f.request('/v1/catalog',{'If-None-Match':r.headers.get('etag')})).status,304);
 assert.equal((await f.request(`/v1/books/${id}/download`)).status,404);assert.equal((await f.request(`/v1/covers/${id}`)).status,404);
 assert.ok(!f.log.some(x=>x.includes('releases')));
});
test('health, routes, queries, method and rate limits reveal no origin',async()=>{
 const f=fixture();assert.deepEqual(await(await f.request('/healthz')).json(),{status:'up'});
 for(const path of ['/v1/books/unknown/download','/v1/assets/2','/v1/catalog?path=private'])assert.equal((await f.request(path)).status,404);
 assert.equal((await f.request('/v1/catalog',{},'POST')).status,405);
 assert.equal((await f.handle(new Request('https://x/v1/catalog'),{RATE_LIMITER:{limit:async()=>({success:false})}})).status,429);
 assert.equal((await f.handle(new Request('https://x/v1/catalog'),{})).status,503);
});
test('missing credentials and GitHub failures return planned-only without stale assets',async()=>{
 for(const code of [401,403,404,429,500]) {
  const h=createHandler(()=>({json:async()=>{throw new Error('private upstream '+code);}}));
  const r=await h(new Request('https://x/v1/catalog'),env);assert.equal(r.headers.get('x-library-state'),'planned-only');assert.ok((await r.json()).books.every(b=>!b.package&&!b.thumbnail));
  const failed=await h(new Request(`https://x/v1/books/${id}/download`),env);assert.equal(failed.status,503);assert.ok(!(await failed.text()).includes('private'));
 }
});
test('approved planned cover remains nondownloadable and integrity checked',async()=>{
 const f=fixture();await f.approveCover();const c=await(await f.request('/v1/catalog')).json();assert.equal(c.books[0].availability,'planned');assert.equal(c.books[0].thumbnail.url,`https://catalog.example/v1/covers/${id}`);assert.ok(!c.books[0].package);
 assert.equal((await f.request(`/v1/covers/${id}`)).status,200);f.files['covers/test.png'][0]=0;assert.equal((await f.request(`/v1/covers/${id}`)).status,503);
 delete f.files['approvals/test-cover.json'];assert.ok(!(await(await f.request('/v1/catalog')).json()).books[0].thumbnail);
});
test('approval required; private manifest failures never advertise releases',async()=>{
 for(const mutate of [f=>delete f.files['approvals/test-book.json'],f=>delete f.files['approvals/test-preflight.json'],f=>f.files['approvals/test-preflight.json'].validatorExitCodes.audio=1,f=>f.files['approvals/test-book.json'].approved=false,f=>f.files['approvals/test-book.json'].packageSHA256='0'.repeat(64),f=>f.files['catalog/approved-packages.json'].entries[0].bookID='unknown',f=>f.files['catalog/approved-packages.json'].entries[0].approvalRecord='../private',f=>f.files['approvals/test-book.json'].technicalGate='failed']){
  const f=fixture();await f.approveBook();mutate(f);const c=await(await f.request('/v1/catalog')).json();assert.ok(c.books.every(b=>!b.package));assert.equal((await f.request(`/v1/books/${id}/download`)).status,503);
 }
});
test('release missing, mutable or wrong digest/size fails closed',async()=>{
 for(const change of [{immutable:false},{draft:true},{assets:[]},{assets:[{id:2,state:'uploaded',size:1,digest:'sha256:'+'a'.repeat(64)}]}]){
  const f=fixture();await f.approveBook();const original=f.gh.json;f.gh.json=async p=>p.endsWith('/releases/1')?{...await original(p),...change}:original(p);
  assert.ok(!(await(await f.request('/v1/catalog')).json()).books[0].package);
 }
});
test('approved proxy streams exact bytes and Range safely restarts with 200',async()=>{
 const f=fixture();await f.approveBook();const c=await(await f.request('/v1/catalog')).json();assert.equal(c.books[0].package.url,`https://catalog.example/v1/books/${id}/download`);
 assert.ok(!JSON.stringify(c).includes(REPO));assert.ok(!JSON.stringify(c).includes('releaseAssetID'));
 for(const headers of [{},{Range:'bytes=7-','If-Range':'old'}]){const r=await f.request(`/v1/books/${id}/download`,headers);assert.equal(r.status,200);assert.equal(r.headers.get('Accept-Ranges'),'none');assert.equal(r.headers.get('Location'),null);assert.equal(r.headers.get('Authorization'),null);assert.equal(r.headers.get('Content-Range'),null);assert.deepEqual(new Uint8Array(await r.arrayBuffer()),f.payload);}
});
test('stream size mismatch cannot complete and client cancellation reaches upstream',async()=>{
 const f=fixture();await f.approveBook();f.gh.stream=async()=>new Response('bad',{headers:{'Content-Length':String(f.payload.length)}});
 const r=await f.request(`/v1/books/${id}/download`);await assert.rejects(()=>r.arrayBuffer());
 let cancelled=false;f.gh.stream=async()=>new Response(new ReadableStream({cancel(){cancelled=true;}}),{headers:{'Content-Length':String(f.payload.length)}});
 const response=await f.request(`/v1/books/${id}/download`);await response.body.cancel();assert.equal(cancelled,true);
});
test('GitHub 302 followed server-side with no Authorization or Range on CDN',async()=>{
 const requests=[];const gh=new GitHub({},async(url,options)=>{requests.push({url,options});if(requests.length===1)return new Response(null,{status:302,headers:{Location:'https://release-assets.githubusercontent.com/test?sig=x'}});return new Response('exact',{headers:{'Content-Length':'5'}});});gh.token=async()=> 'fixture-token';
 assert.equal(await(await gh.stream(2)).text(),'exact');assert.equal(requests[0].options.headers.Authorization,'Bearer fixture-token');assert.equal(requests[1].options.headers.Authorization,undefined);assert.equal(requests[1].options.headers.Range,undefined);
 for(const target of ['http://release-assets.githubusercontent.com/x','https://evil.test/x','https://user:secret@objects.githubusercontent.com/x']){gh.fetcher=async()=>new Response(null,{status:302,headers:{Location:target}});await assert.rejects(()=>gh.stream(2));}
});
test('JWT supports GitHub PEM, expires within 10 minutes, token scopes one repo/read',async()=>{
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});const e={GITHUB_APP_ID:'123',GITHUB_INSTALLATION_ID:'456',GITHUB_APP_PRIVATE_KEY:privateKey.export({type:'pkcs1',format:'pem'})};
 const jwt=await appJWT(e);const [head,payload,signature]=jwt.split('.');const verify=createVerify('RSA-SHA256');verify.update(head+'.'+payload);assert.ok(verify.verify(publicKey,Buffer.from(signature,'base64url')));const claims=JSON.parse(Buffer.from(payload,'base64url'));assert.ok(claims.exp-claims.iat<=600);
 let calls=0;const gh=new GitHub(e,async(url,options)=>{calls++;assert.equal(options.headers['Content-Type'],'application/json');assert.deepEqual(JSON.parse(options.body),{repositories:['LifeIsLearned-Published'],permissions:{contents:'read'}});return Response.json({token:'synthetic-token',expires_at:new Date(Date.now()+3600000).toISOString()});});assert.equal(await gh.token(),'synthetic-token');await gh.token();assert.equal(calls,1);
});

test('bundled planned metadata matches the source contract and public origins fail closed',async()=>{
 assert.deepEqual(canonical,JSON.parse(readFileSync(new URL('../../../Catalog/Remote-Catalog-001.json',import.meta.url),'utf8')));
 const f=fixture();const original=f.gh.json;f.gh.json=async p=>p===`/repos/${REPO}`?{private:false,full_name:REPO}:original(p);
 const r=await f.request('/v1/catalog');assert.equal(r.headers.get('x-library-state'),'planned-only');assert.ok((await r.json()).books.every(b=>!b.package));
});
