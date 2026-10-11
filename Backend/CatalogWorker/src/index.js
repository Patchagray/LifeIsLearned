import {GitHub, digest, Unavailable} from './github.js';
import {catalog, snapshot, knownID, coverBytes} from './catalog.js';
const baseHeaders={'X-Content-Type-Options':'nosniff','Cache-Control':'no-store'};
function json(value,status=200,headers={}) {return new Response(JSON.stringify(value),{status,headers:{...baseHeaders,'Content-Type':'application/json',...headers}});}
const unavailable=()=>json({error:'Library temporarily unavailable. Please retry.'},503,{'Retry-After':'60'});
function boundedStream(body, expected) {
  let count=0; const reader=body.getReader();
  return new ReadableStream({
    async pull(controller) {
      try {const {value,done}=await reader.read();if(done){if(count!==expected)throw new Unavailable();controller.close();return;}
        count+=value.byteLength;if(count>expected)throw new Unavailable();controller.enqueue(value);
      } catch {await reader.cancel();controller.error(new Error('Download interrupted. Retry.'));}
    },cancel(reason){return reader.cancel(reason);}
  });
}
export function createHandler(githubFactory=(env)=>new GitHub(env)) {
  return async function handle(request,env) {
    const url=new URL(request.url);
    if(request.method!=='GET')return json({error:'Method not allowed'},405,{Allow:'GET'});
    if(url.search || url.hash)return json({error:'Not found'},404);
    if(url.pathname==='/healthz')return json({status:'up'});
    const cover=url.pathname.match(/^\/v1\/covers\/([a-z0-9-]+)$/);
    const book=url.pathname.match(/^\/v1\/books\/([a-z0-9-]+)\/download$/);
    if(url.pathname!=='/v1/catalog' && !(cover&&knownID(cover[1])) && !(book&&knownID(book[1])))return json({error:'Not found'},404);
    if(!env.RATE_LIMITER)return unavailable();
    try {if(!(await env.RATE_LIMITER.limit({key:request.headers.get('CF-Connecting-IP')||'unknown'})).success)return json({error:'Please retry shortly'},429,{'Retry-After':'60'});}catch{return unavailable();}
    let state,github;
    try {github=githubFactory(env);state=await snapshot(github);}catch {
      // No authenticated origin means no assets; never reuse an old approved overlay.
      if(url.pathname!=='/v1/catalog')return unavailable();
      return json(catalog(null,url.origin),200,{'X-Library-State':'planned-only'});
    }
    try {
      if(url.pathname==='/v1/catalog') {
        const result=catalog(state,url.origin),etag='"'+await digest(new TextEncoder().encode(JSON.stringify(result)))+'"';
        if(request.headers.get('If-None-Match')===etag)return new Response(null,{status:304,headers:{...baseHeaders,ETag:etag}});
        return json(result,200,{ETag:etag,'Cache-Control':'private, max-age=0, must-revalidate'});
      }
      if(cover) {
        const e=state.covers.get(cover[1]);if(!e)return json({error:'Not found'},404);
        const bytes=await coverBytes(github,state,e);
        return new Response(bytes,{headers:{...baseHeaders,'Content-Type':e.mediaType,'Content-Length':String(e.bytes),ETag:'"'+e.sha256+'"'}});
      }
      const e=state.packages.get(book[1]);if(!e)return json({error:'Not found'},404);
      const upstream=await github.stream(e.releaseAssetID);
      if(Number(upstream.headers.get('Content-Length'))!==e.bytes || upstream.headers.has('Content-Range') || !upstream.body) {await upstream.body?.cancel();throw new Unavailable();}
      return new Response(boundedStream(upstream.body,e.bytes),{status:200,headers:{...baseHeaders,
        'Content-Type':'application/json','Content-Disposition':`attachment; filename="${e.bookID}-r${e.collectionRevision}.json"`,
        'Content-Length':String(e.bytes),'Accept-Ranges':'none',ETag:'"'+e.sha256+'"'}});
    } catch {return unavailable();}
  };
}
export default {fetch:createHandler()};
