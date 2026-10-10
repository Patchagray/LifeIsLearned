#!/usr/bin/env python3
"""Fail-closed FUTURE book release preflight. Does not upload or publish anything.

Usage:
  python3 publication_preflight.py --package final-book.json --approval approved.json \
      --output /private/local/release-review

No --force, --skip-audio or --auto-approve exists. CI must treat nonzero as blocking.
This guard does NOT establish authenticity of the owner approval reference by itself;
Codex must obtain explicit out-of-band owner sign-off and verify its provenance.
"""
import base64
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Tools/validate_package.py"
CANONICAL_IDS = {b['id'] for b in json.loads((ROOT/'Catalog/Catalog-001.json').read_text())['books']}
FIXTURE_HASH = hashlib.sha256((ROOT/'Tools/Fixtures/narration-tone.mp3').read_bytes()).hexdigest()
HEX64 = re.compile(r"^[0-9a-f]{64}$")

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def policy_errors(pkg: dict, approval: dict, raw: bytes, audio_report_raw: bytes):
    errors=[]
    if not isinstance(approval, dict): approval={}
    if not isinstance(pkg, dict): return ["Invalid package"]
    book=pkg.get("book") if isinstance(pkg.get("book"),dict) else {}
    book_id=book.get("id")
    lessons=book.get("lessons") or []
    audio=pkg.get("audioAssets")
    revision=pkg.get("collectionRevision")
    if book_id not in CANONICAL_IDS or type(revision) is not int or revision<=0:
        errors.append("Missing canonical book ID or positive collection revision")
    if not isinstance(lessons,list) or not lessons: return ["Empty/invalid lesson list"]
    if not isinstance(audio,dict) or not audio: errors.append("No premium audioAssets table")
    if book.get('isDemo') is True or any(x in str(book.get('title','')).lower() for x in ('synthetic', 'fixture', 'test tone')):
        errors.append("Synthetic/demo content is not a production release")
    hashes = {}
    if isinstance(audio, dict):
        for key, asset in audio.items():
            try:
                h=digest(base64.b64decode(asset['data'],validate=True));hashes[key]=h
                if h==FIXTURE_HASH: errors.append("Synthetic tone fixture cannot be distributed")
            except (KeyError,TypeError,ValueError): errors.append("Invalid packaged audio")
    scripts_by_audio={}
    for lesson in lessons:
        if not isinstance(lesson,dict):
            errors.append("Invalid idea object");continue
        idea=lesson.get("id","<unknown>")
        bundle=lesson.get("narration")
        if not isinstance(bundle,dict) or not isinstance(bundle.get("segments"),list) or not bundle.get("segments"):
            errors.append(f"{idea}: no complete premium narration bundle")
            continue
        prov=bundle.get("provenance")
        if not isinstance(prov,dict) or prov.get("provider")!="elevenlabs":
            errors.append(f"{idea}: narration provenance is not ElevenLabs")
            continue
        for key in ("guideVoiceID","storytellerVoiceID"):
            if not isinstance(prov.get(key),str) or not prov[key].strip():
                errors.append(f"{idea}: missing approved production {key}")
        for segment in bundle['segments']:
            if not isinstance(segment,dict): errors.append("Invalid segment");continue
            h=hashes.get(segment.get('assetID')); script=segment.get('scriptSHA256')
            if h and h in scripts_by_audio and scripts_by_audio[h]!=script: errors.append("Identical MP3 bytes assigned to different spoken scripts")
            if h: scripts_by_audio[h]=script
        for key in ('modelID','producedAt'):
            if not prov.get(key): errors.append(f"{idea}: missing production {key}")
        # Segment completeness, script hashes, duration, decoding and audio timing
        # MUST be established by the real app validator --audio-gate below.
    if not isinstance(approval,dict) or approval.get("type")!="life-is-learned-book-release-approval-v1" or approval.get("approved") is not True:
        errors.append("Explicit owner approval record absent or not approved")
    elif approval.get("bookID")!=book_id or approval.get("collectionRevision")!=revision:
        errors.append("Approval is for a different book ID or revision")
    if approval.get("packageSHA256") != digest(raw):
        errors.append("Owner approval SHA-256 does not bind this exact final package")
    if approval.get("audioQAReportSHA256") != digest(audio_report_raw):
        errors.append("Audio QA report SHA-256 does not match owner approval")
    for key in ("approvedAt","approvalReference","approvedBy","approvedGuideVoiceID","approvedStorytellerVoiceID"):
        if not isinstance(approval.get(key),str) or not approval[key].strip():
            errors.append(f"Owner approval missing {key}")
    for lesson in lessons:
        if not isinstance(lesson,dict): continue
        prov=((lesson.get("narration") or {}).get("provenance") or {}) if isinstance(lesson.get("narration"),dict) else {}
        if not isinstance(prov,dict): continue
        for key,approval_key in (("guideVoiceID","approvedGuideVoiceID"),("storytellerVoiceID","approvedStorytellerVoiceID")):
            if prov.get(key) and approval.get(approval_key) and prov[key]!=approval[approval_key]:
                errors.append(f"{lesson.get('id')}: packaged {key} differs from approved voice")
    if approval.get('packageBytes') != len(raw): errors.append("Approval byte size does not match")
    if approval.get('speechAuditioned') is not True: errors.append("Owner must confirm the exact audio was auditioned as speech")
    return errors


def technical_reports(package, output):
    """Always run the repository's authoritative gates; callers cannot replace it."""
    reports={}; exits={}
    for name,flag in [('authoring','--authoring-gate'),('audio','--audio-gate')]:
        target=output/(name+'-qa.json')
        result=subprocess.run([sys.executable,str(VALIDATOR),str(package),flag,'--report',str(target)],capture_output=True,text=True,timeout=1200)
        exits[name]=result.returncode
        if not target.is_file(): raise ValueError("Validator did not produce its report")
        reports[name]=json.loads(target.read_bytes())
    return reports,exits


def report_errors(reports,exits,package):
    errors=[]
    if exits != {'authoring':0,'audio':0}: errors.append("Authoritative authoring/audio gate failed")
    if reports['authoring'].get('authoringGate')!='passed' or reports['authoring'].get('errors') or reports['audio'].get('errors'):errors.append("Failed authoring/audio report")
    packages=reports['audio'].get('packages',[])
    if len(packages)!=1: return errors+["Missing audio QA"]
    audio=packages[0].get('audio',{}); ideas=audio.get('ideas',[])
    expected=[(l['id'],l['revision']) for l in package['book']['lessons']]
    if [(i.get('id'),i.get('revision')) for i in ideas]!=expected: errors.append("Audio report does not cover every exact idea")
    if audio.get('assetErrors') or any(i.get('premiumNarration')!='complete' or i.get('errors') or not 0<i.get('measuredCoreSeconds',0)<=300 for i in ideas): errors.append("Every idea must have complete valid studio audio within 300 seconds")
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package",type=Path,required=True)
    parser.add_argument("--approval",type=Path,help="Absent approval produces QA reports and a denied result")
    parser.add_argument("--validator",type=Path,default=VALIDATOR,help="Compatibility argument; must resolve to this repository's validator")
    parser.add_argument("--output",type=Path,required=True,help="New private local directory for exact QA reports")
    args=parser.parse_args()
    try:
        if args.validator.resolve()!=VALIDATOR.resolve(): raise ValueError("Use the authoritative repository validator")
        if args.package.stat().st_size>64*1024*1024: raise ValueError("Package exceeds 64 MiB")
        raw=args.package.read_bytes();pkg=json.loads(raw)
        approval=json.loads(args.approval.read_bytes()) if args.approval else {}
        args.output.mkdir(parents=True,exist_ok=False)
        reports,exits=technical_reports(args.package,args.output)
        audio_raw=(args.output/'audio-qa.json').read_bytes()
        errors=report_errors(reports,exits,pkg)+policy_errors(pkg,approval,raw,audio_raw)
        result={'schemaVersion':1,'bookID':pkg['book']['id'],'collectionRevision':pkg['collectionRevision'],
                'packageSHA256':digest(raw),'packageBytes':len(raw),'audioQAReportSHA256':digest(audio_raw),
                'validatorExitCodes':exits,'errors':errors,'result':'denied' if errors else 'passed',
                'scope':'Local preflight only; owner approval provenance must be independently verified before any upload.'}
        (args.output/'preflight.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2))
        return 1 if errors else 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired,json.JSONDecodeError) as exc:
        print(f"DENIED: preflight error: {exc}",file=sys.stderr)
        return 1
if __name__=="__main__": raise SystemExit(main())
