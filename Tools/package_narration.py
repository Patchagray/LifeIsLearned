"""Package reviewed, normalized MP3 masters without changing any lesson content."""
import argparse
import base64
import copy
import json
import math
from pathlib import Path
from narration_audio import manifest, inspect_mp3, coarse_cues, valid_cues, sha, TOTAL_BYTES
from validate_package import read_package, content, unique_object

def package_audio(package, script_manifest, clips, collection_revision, cues=None, provenance=None):
    expected = manifest(package)
    if script_manifest != expected: raise ValueError('Manifest differs from current exact scripts, identities or revisions; export it again.')
    if type(collection_revision) is not int or collection_revision <= package['collectionRevision']:
        raise ValueError('Sound Production requires a newer collection revision; idea revisions remain unchanged.')
    wanted = {s['file'] for idea in expected['ideas'] for s in idea['segments']}
    found = {p.name for p in Path(clips).iterdir() if p.is_file()}
    if wanted != found: raise ValueError(f'Clip directory differs from manifest. Missing: {sorted(wanted-found)}; unknown: {sorted(found-wanted)}')
    if cues is not None and set(cues) - wanted: raise ValueError('Cue file names must exist in the script manifest.')
    result = copy.deepcopy(package); result['collectionRevision'] = collection_revision; result['audioAssets'] = {}
    total = 0
    for lesson, idea in zip(result['book']['lessons'], expected['ideas']):
        segments = []
        for script in idea['segments']:
            path = Path(clips) / script['file']; duration = inspect_mp3(path); raw = path.read_bytes(); total += len(raw)
            if total > TOTAL_BYTES: raise ValueError('Audio exceeds 40 MiB.')
            asset_id = 'narration-' + sha(lesson['id'] + '\0' + script['id'])
            result['audioAssets'][asset_id] = dict(mediaType='audio/mpeg', data=base64.b64encode(raw).decode(), durationMilliseconds=duration)
            mapping = cues.get(script['file']) if cues is not None and script['file'] in cues else coarse_cues(script['text'], duration)
            if not valid_cues(mapping, script['text'], duration): raise ValueError('Invalid cue coordinates/timing: ' + script['id'])
            segments.append(dict(id=script['id'], assetID=asset_id, role=script['role'], scriptSHA256=script['scriptSHA256'], durationMilliseconds=duration, cues=mapping))
        lesson['narration'] = dict(schemaVersion=1, segments=segments)
        if provenance is not None:
            allowed = {'provider','modelID','guideVoiceID','guideVoiceName','storytellerVoiceID','storytellerVoiceName','producedAt'}
            if set(provenance) - allowed or provenance.get('provider') != 'elevenlabs': raise ValueError('Use ElevenLabs provenance fields only; never credentials.')
            if any(not isinstance(v,str) for k,v in provenance.items() if k!='producedAt'): raise ValueError('Provenance values must be strings.')
            if 'producedAt' in provenance and (type(provenance['producedAt']) not in (int,float) or not math.isfinite(provenance['producedAt'])): raise ValueError('producedAt uses seconds since 2001-01-01 UTC, matching the native package encoder.')
            lesson['narration']['provenance'] = provenance
    content(result)
    encoded = json.dumps(result, ensure_ascii=False, separators=(',',':')).encode()
    if len(encoded) > 64*1024*1024: raise ValueError('The complete base64 JSON exceeds 64 MiB.')
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['package','manifest','clips','output']: parser.add_argument(name,type=Path)
    parser.add_argument('--collection-revision',type=int,required=True)
    parser.add_argument('--cues',type=Path); parser.add_argument('--provenance',type=Path)
    args=parser.parse_args()
    def read(path): return json.loads(path.read_text(),object_pairs_hook=unique_object) if path else None
    original,_=read_package(args.package);content(original)
    result=package_audio(original,read(args.manifest),args.clips,args.collection_revision,read(args.cues),read(args.provenance))
    # Atomic output; never replace the reviewed input package.
    if args.output.resolve()==args.package.resolve(): raise ValueError('Choose a separate output package.')
    temporary=args.output.with_name(args.output.name+'.tmp')
    temporary.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n');temporary.replace(args.output)
if __name__=='__main__': main()
