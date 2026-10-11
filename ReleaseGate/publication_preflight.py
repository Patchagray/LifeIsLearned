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
        if not isinstance(prov.get('modelID'),str) or not prov['modelID'].strip():
            errors.append(f"{idea}: missing production modelID")
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
    for key in ("approvedAt","approvalReference","approvedBy","approvedStorytellerVoiceID"):
        if not isinstance(approval.get(key),str) or not approval[key].strip():
            errors.append(f"Owner approval missing {key}")
    guide_ids=approval.get('approvedGuideVoiceIDs')
    if guide_ids is None and isinstance(approval.get('approvedGuideVoiceID'),str):
        guide_ids=[approval['approvedGuideVoiceID']]
    if (not isinstance(guide_ids,list) or not guide_ids or len(guide_ids)>8 or
            any(not isinstance(v,str) or not v.strip() for v in guide_ids) or len(set(guide_ids))!=len(guide_ids)):
        errors.append('Owner approval needs one or more unique approved Guide voice IDs')
        guide_ids=[]
    packaged_guide_ids=set()
    for lesson in lessons:
        if not isinstance(lesson,dict): continue
        prov=((lesson.get("narration") or {}).get("provenance") or {}) if isinstance(lesson.get("narration"),dict) else {}
        if not isinstance(prov,dict): continue
        guide_id=prov.get('guideVoiceID')
        if isinstance(guide_id,str):
            packaged_guide_ids.add(guide_id)
            if guide_id not in guide_ids:
                errors.append(f"{lesson.get('id')}: packaged Guide voice is not owner-approved")
        storyteller_id=prov.get('storytellerVoiceID')
        if storyteller_id and approval.get('approvedStorytellerVoiceID') and storyteller_id!=approval['approvedStorytellerVoiceID']:
            errors.append(f"{lesson.get('id')}: packaged storytellerVoiceID differs from approved voice")
    if isinstance(guide_ids,list) and set(guide_ids)!=packaged_guide_ids:
        errors.append('Approved Guide voice IDs must exactly match packaged provenance')
    if approval.get('packageBytes') != len(raw): errors.append("Approval byte size does not match")
    if approval.get('speechAuditioned') is not True: errors.append("Owner must confirm the exact audio was auditioned as speech")
    return errors


def policy_warnings(pkg: dict):
    """Optional format provenance is surfaced honestly without fabricating timestamps."""
    warnings=[]
    lessons=(pkg.get('book') or {}).get('lessons',[]) if isinstance(pkg,dict) else []
    missing=[lesson.get('id','<unknown>') for lesson in lessons
             if not (((lesson.get('narration') or {}).get('provenance') or {}).get('producedAt'))]
    if missing:
        warnings.append('Narration producedAt is absent (optional in formatVersion 2) for: '+', '.join(missing))
    guide_ids={((lesson.get('narration') or {}).get('provenance') or {}).get('guideVoiceID') for lesson in lessons}
    guide_ids.discard(None)
    if len(guide_ids)>1:
        warnings.append('Package uses multiple Guide voices; every ID must be listed in the exact-hash owner approval.')
    return warnings


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


def accepted_timing_waiver(pkg, raw, approval, reports, exits):
    """Owner may waive only reported timing/estimate failures for these exact bytes."""
    waiver = approval.get('timingWaiver', {})
    actual = reports['authoring'].get('errors', []) + reports['audio'].get('errors', [])
    pattern = r"^[a-z0-9-]+: (?:[0-9.]+ seconds exceeds the 300-second whole-idea budget\. Shorten the content; do not speed up playback\.|estimatedMinutes must be [0-9]+ for the reference whole-idea plan\.|measured studio core exceeds 300 seconds)$"
    if not actual or any(not re.fullmatch(pattern, e) for e in actual): return None
    if (approval.get('approved') is not True or approval.get('bookID') != pkg['book']['id'] or
        approval.get('collectionRevision') != pkg['collectionRevision'] or approval.get('packageSHA256') != digest(raw) or
        not isinstance(waiver, dict) or waiver.get('type') != 'life-is-learned-timing-waiver-v1' or
        waiver.get('packageSHA256') != digest(raw) or waiver.get('validatorErrors') != actual or
        not all(isinstance(waiver.get(k), str) and waiver[k].strip() for k in ('approvedBy', 'approvedAt', 'approvalReference')) or
        exits != {'authoring': 1, 'audio': 1}): return None
    audio = reports['audio'].get('packages', [{}])[0].get('audio', {})
    ideas = audio.get('ideas', [])
    expected = [(l['id'], l['revision']) for l in pkg['book']['lessons']]
    limit = waiver.get('maximumMeasuredCoreSeconds', 0)
    if (not isinstance(limit, (int, float)) or not 300 < limit <= 360 or audio.get('assetErrors') or
        [(i.get('id'), i.get('revision')) for i in ideas] != expected or
        any(i.get('premiumNarration') != 'complete' or i.get('errors') or not 0 < i.get('measuredCoreSeconds', 0) <= limit for i in ideas)):
        return None
    return waiver


def approval_errors(package, approval, package_raw, audio_raw, preflight_raw):
    errors=policy_errors(package,approval,package_raw,audio_raw)
    if not isinstance(approval,dict) or approval.get('preflightReportSHA256')!=digest(preflight_raw):
        errors.append('Owner approval does not bind the exact technical preflight report')
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
        errors=report_errors(reports,exits,pkg)
        waiver=accepted_timing_waiver(pkg,raw,approval,reports,exits)
        if waiver: errors=[]
        technical={'schemaVersion':1,'bookID':pkg['book']['id'],'collectionRevision':pkg['collectionRevision'],
                'packageSHA256':digest(raw),'packageBytes':len(raw),'audioQAReportSHA256':digest(audio_raw),
                'validatorExitCodes':exits,'errors':errors,'warnings':policy_warnings(pkg),
                'result':'denied' if errors else 'passed',
                'scope':'Deterministic technical report; the exact-hash owner approval is recorded separately.'}
        if waiver:
            technical['result']='passed-with-owner-timing-waiver'
            technical['timingWaiver']=waiver
        preflight_raw=(json.dumps(technical,indent=2)+'\n').encode()
        (args.output/'preflight.json').write_bytes(preflight_raw)
        owner_errors=approval_errors(pkg,approval,raw,audio_raw,preflight_raw)
        decision={'schemaVersion':1,'bookID':pkg['book']['id'],'collectionRevision':pkg['collectionRevision'],
                  'packageSHA256':digest(raw),'packageBytes':len(raw),'audioQAReportSHA256':digest(audio_raw),
                  'preflightReportSHA256':digest(preflight_raw),'validatorExitCodes':exits,
                  'errors':errors+owner_errors,'warnings':technical['warnings'],
                  'result':'passed' if not errors and not owner_errors else 'denied',
                  'scope':'Local decision only; verify owner approval provenance before upload.'}
        if waiver and decision['result']=='passed':
            decision['result']='passed-with-owner-timing-waiver'
            decision['timingWaiver']=waiver
        (args.output/'release-decision.json').write_text(json.dumps(decision,indent=2)+'\n')
        print(json.dumps(decision,indent=2))
        return 0 if decision['result'] in ('passed','passed-with-owner-timing-waiver') else 1
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired,json.JSONDecodeError) as exc:
        print(f"DENIED: preflight error: {exc}",file=sys.stderr)
        return 1
if __name__=="__main__": raise SystemExit(main())
