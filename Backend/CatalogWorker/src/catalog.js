import planned from './planned.json' with { type: 'json' };
import { REPO, Unavailable, digest } from './github.js';
export const canonical=planned;
const ids=new Set(planned.books.map(b=>b.id));
export const knownID=(id)=>ids.has(id);
const require=(ok)=>{if(!ok)throw new Unavailable();};
const hash=(s)=>typeof s==='string' && /^[a-f0-9]{64}$/.test(s);
const positive=(n)=>Number.isSafeInteger(n)&&n>0;
const parse=(bytes)=>JSON.parse(new TextDecoder().decode(bytes));
function entries(value) {
  require(value.schemaVersion===1 && Array.isArray(value.entries) && value.entries.length<=50);
  require(new Set(value.entries.map(e=>e.bookID)).size===value.entries.length);
  for(const e of value.entries)require(knownID(e.bookID));
  return value.entries;
}
function common(entry, approval, kind) {
  require(hash(entry.sha256)&&positive(entry.bytes));
  require(approval.type===`life-is-learned-${kind}-approval-v1` && approval.approved===true && approval.bookID===entry.bookID);
  for(const key of ['approvedBy','approvalReference','approvedAt'])require(typeof approval[key]==='string'&&approval[key].trim().length>0);
  require(Number.isFinite(Date.parse(approval.approvedAt)));
}
export async function snapshot(github) {
  const repo=await github.json(`/repos/${REPO}`);require(repo.private===true && repo.full_name===REPO);
  const commit=await github.json(`/repos/${REPO}/commits/main`);require(/^[a-f0-9]{40}$/.test(commit.sha));
  const ref=commit.sha;
  // Pin every manifest/approval/cover read to the same commit, never a mixture.
  const base=parse(await github.file('catalog/Remote-Catalog-001.json',ref));
  require(JSON.stringify(base)===JSON.stringify(planned));
  const packages=entries(parse(await github.file('catalog/approved-packages.json',ref)));
  const covers=entries(parse(await github.file('catalog/approved-covers.json',ref)));
  const approvedPackages=new Map(),approvedCovers=new Map();
  async function approval(e) {
    require(/^approvals\/[a-z0-9-]+\.json$/.test(e.approvalRecord));
    return parse(await github.file(e.approvalRecord,ref,32768));
  }
  for(const e of covers) {
    const a=await approval(e);common(e,a,'cover-preview');
    require(e.bytes<=512*1024 && a.sha256===e.sha256 && a.bytes===e.bytes &&
      ['image/png','image/jpeg'].includes(e.mediaType) && a.mediaType===e.mediaType &&
      /^covers\/[a-z0-9-]+\.(png|jpg|jpeg)$/.test(e.path));
    approvedCovers.set(e.bookID,e);
  }
  for(const e of packages) {
    const a=await approval(e);common(e,a,'book-release');
    require(e.bytes<=64*1024*1024 && positive(e.collectionRevision)&&positive(e.releaseAssetID)&&positive(e.releaseID));
    const guideVoices=Array.isArray(a.approvedGuideVoiceIDs)?a.approvedGuideVoiceIDs:[a.approvedGuideVoiceID];
    require(a.collectionRevision===e.collectionRevision && a.packageSHA256===e.sha256 && a.packageBytes===e.bytes &&
      hash(a.audioQAReportSHA256) && Array.isArray(guideVoices)&&guideVoices.length>0&&guideVoices.length<=8&&
      guideVoices.every(v=>typeof v==='string'&&v.trim())&&new Set(guideVoices).size===guideVoices.length&&
      typeof a.approvedStorytellerVoiceID==='string'&&a.approvedStorytellerVoiceID.trim() &&
      ['all-idea-elevenlabs-passed','all-idea-elevenlabs-passed-with-owner-timing-waiver'].includes(a.technicalGate) && hash(a.preflightReportSHA256));
    require(/^approvals\/[a-z0-9-]+\.json$/.test(e.preflightReportRecord));
    const reportBytes=await github.file(e.preflightReportRecord,ref,65536);
    require(await digest(reportBytes)===a.preflightReportSHA256);
    const report=parse(reportBytes);
    const normal=report.result==='passed' && report.validatorExitCodes?.authoring===0 && report.validatorExitCodes?.audio===0 && a.technicalGate==='all-idea-elevenlabs-passed';
    const w=a.timingWaiver;
    const waived=report.result==='passed-with-owner-timing-waiver' && a.technicalGate==='all-idea-elevenlabs-passed-with-owner-timing-waiver' &&
      report.validatorExitCodes?.authoring===1 && report.validatorExitCodes?.audio===1 &&
      w?.type==='life-is-learned-timing-waiver-v1' && w.packageSHA256===e.sha256 &&
      Number.isFinite(w.maximumMeasuredCoreSeconds) && w.maximumMeasuredCoreSeconds>300 && w.maximumMeasuredCoreSeconds<=360 &&
      ['approvedBy','approvedAt','approvalReference'].every(k=>typeof w[k]==='string'&&w[k].trim()) &&
      Array.isArray(w.validatorErrors)&&w.validatorErrors.length>0&&w.validatorErrors.every(x=>typeof x==='string'&&/^[a-z0-9-]+: (?:[0-9.]+ seconds exceeds the 300-second whole-idea budget\. Shorten the content; do not speed up playback\.|estimatedMinutes must be [0-9]+ for the reference whole-idea plan\.|measured studio core exceeds 300 seconds)$/.test(x)) &&
      JSON.stringify(w)===JSON.stringify(report.timingWaiver);
    require((normal || waived) && Array.isArray(report.errors) && report.errors.length===0 &&
      report.bookID===e.bookID && report.collectionRevision===e.collectionRevision &&
      report.packageSHA256===e.sha256 && report.packageBytes===e.bytes && report.audioQAReportSHA256===a.audioQAReportSHA256);
    const release=await github.json(`/repos/${REPO}/releases/${e.releaseID}`);
    require(release.id===e.releaseID && release.immutable===true && release.draft===false && Array.isArray(release.assets));
    const asset=release.assets.find(x=>x.id===e.releaseAssetID);
    require(asset && asset.state==='uploaded' && asset.size===e.bytes && asset.digest==='sha256:'+e.sha256);
    approvedPackages.set(e.bookID,e);
  }
  return {ref,packages:approvedPackages,covers:approvedCovers};
}
export function catalog(state,origin) {
  const result=structuredClone(planned);
  for(const b of result.books) {
    const c=state?.covers.get(b.id),p=state?.packages.get(b.id);
    if(c)b.thumbnail={url:`${origin}/v1/covers/${b.id}`,sha256:c.sha256,bytes:c.bytes};
    if(p){b.availability='available';b.package={collectionRevision:p.collectionRevision,url:`${origin}/v1/books/${b.id}/download`,sha256:p.sha256,bytes:p.bytes};}
  }
  return result;
}
export async function coverBytes(github, state, entry) {
  const bytes=await github.file(entry.path,state.ref,512*1024);
  require(bytes.length===entry.bytes && await digest(bytes)===entry.sha256);
  const png=bytes.length>=24&&[137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v);
  const jpeg=bytes.length>=4&&bytes[0]===255&&bytes[1]===216&&bytes.at(-2)===255&&bytes.at(-1)===217;
  require(entry.mediaType==='image/png'?png:jpeg);return bytes;
}
