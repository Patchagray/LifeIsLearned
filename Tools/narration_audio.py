"""Deterministic Sound Production contract. FFmpeg is authoring-only, never an app dependency."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave
from lesson_timing import page_text, question_text, feedback, completion_text

SEGMENT_BYTES = 2 * 1024 * 1024
TOTAL_BYTES = 40 * 1024 * 1024
MAX_DURATION = 600_000


def sha(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def scripts(lesson):
    result = [dict(id='page:' + p['id'], role=p['role'], text=page_text(p), stage=p['title']) for p in lesson['pages']]
    for q in lesson['questions']:
        result.append(dict(id='question:' + q['id'], role='guide', text=question_text(q), stage='Practice'))
        for c in q['choices']:
            result.append(dict(id=f"feedback:{q['id']}:{c['id']}", role='guide', text=feedback(c, c['id'] == q['correctChoiceID']), stage='Feedback'))
    for score in range(len(lesson['questions']) + 1):
        result.append(dict(id=f'completion:{score}', role='guide', text=completion_text(score, len(lesson['questions'])), stage='Complete'))
    if len({s['id'] for s in result}) != len(result): raise ValueError('Narration IDs collide; use unambiguous page/question/choice identities.')
    for s in result:
        s['scriptSHA256'] = sha(s['text'])
        s['file'] = sha(lesson['id'] + '\0' + s['id']) + '.mp3'
    return result


def manifest(package):
    return dict(schemaVersion=1, bookID=package['book']['id'], collectionRevision=package['collectionRevision'],
                ideas=[dict(id=l['id'], revision=l['revision'], segments=scripts(l)) for l in package['book']['lessons']])


def ffmpeg():
    executable = os.environ.get('LIL_FFMPEG') or shutil.which('ffmpeg')
    if not executable:
        raise ValueError('Sound Production needs FFmpeg. Install it or set LIL_FFMPEG to its executable path.')
    return executable


def inspect_mp3(path):
    path = Path(path)
    if not 0 < path.stat().st_size <= SEGMENT_BYTES:
        raise ValueError('Every MP3 must contain 1 byte–2 MiB.')
    # Full PCM decode catches truncated/corrupt input; keep output bounded on hostile files.
    with tempfile.TemporaryDirectory(prefix='lil-audio-qa-') as directory:
        output = Path(directory) / 'decoded.wav'
        process = subprocess.run([ffmpeg(), '-nostdin', '-hide_banner', '-xerror', '-i', str(path),
                                  '-t', '600.1', '-map', '0:a:0', '-c:a', 'pcm_s16le', str(output)],
                                 capture_output=True, timeout=60)
        log = process.stderr.decode(errors='replace')
        input_log = log.split('Stream mapping:')[0]
        if process.returncode or not re.search(r'Audio: mp3(?:float)?[, ]', input_log):
            raise ValueError('Input must successfully decode as MP3, not a renamed audio file.')
        with wave.open(str(output), 'rb') as audio:
            if audio.getnchannels() != 1:
                raise ValueError('Narration MP3 must be mono.')
            duration = round(audio.getnframes() * 1000 / audio.getframerate())
        if not 0 < duration <= MAX_DURATION:
            raise ValueError('MP3 duration must be positive and at most 600 seconds.')
        return duration


def coarse_cues(text, duration):
    """UTF-16 sentence spans weighted by words; estimated, not forced alignment."""
    spans = [(m.start(), m.end()) for m in re.finditer(r'\S[\s\S]*?(?:[.!?](?=\s|$)|$)', text) if m.end() > m.start()]
    weights = [max(1, len(text[a:b].split())) for a, b in spans]
    total = sum(weights); elapsed = 0; result = []
    for (a, b), weight in zip(spans, weights):
        start = round(duration * elapsed / total); elapsed += weight
        end = round(duration * elapsed / total)
        if end > start:
            result.append(dict(characterStart=len(text[:a].encode('utf-16-le')) // 2,
                               characterLength=len(text[a:b].encode('utf-16-le')) // 2,
                               startMilliseconds=start, endMilliseconds=end))
    return result


def valid_cues(cues, text, duration):
    if cues is None: return True
    if type(duration) is not int or not isinstance(cues, list) or len(cues) > 10000: return False
    length = len(text.encode('utf-16-le')) // 2
    previous_time = previous_character = 0
    for c in cues:
        if not isinstance(c, dict) or any(type(c.get(k)) is not int for k in ('characterStart', 'characterLength', 'startMilliseconds', 'endMilliseconds')): return False
        a, n, start, end = (c[k] for k in ('characterStart', 'characterLength', 'startMilliseconds', 'endMilliseconds'))
        if not (previous_character <= a < a + n <= length and previous_time <= start < end <= duration): return False
        previous_character, previous_time = a + n, end
    return True


def audio_report(package):
    assets = package.get('audioAssets') or {}
    if not isinstance(assets, dict): assets = {}
    decoded, asset_errors = {}, {}
    total = 0
    with tempfile.TemporaryDirectory(prefix='lil-package-audio-') as folder:
        for index, (key, asset) in enumerate(assets.items()):
            try:
                raw = base64.b64decode(asset['data'], validate=True); total += len(raw)
                if asset['mediaType'] != 'audio/mpeg' or type(asset['durationMilliseconds']) is not int or not 0 < asset['durationMilliseconds'] <= MAX_DURATION:
                    raise ValueError('Invalid media type or duration metadata.')
                if len(raw) > SEGMENT_BYTES or total > TOTAL_BYTES: raise ValueError('Audio byte budget exceeded.')
                path = Path(folder) / f'{index}.mp3'; path.write_bytes(raw)
                duration = inspect_mp3(path)
                if abs(duration - asset['durationMilliseconds']) > max(250, asset['durationMilliseconds'] // 20):
                    raise ValueError('Measured MP3 duration differs from metadata.')
                decoded[key] = (duration, len(raw))
            except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
                asset_errors[key] = str(error)
    reports = []
    for lesson in package['book']['lessons']:
        bundle = lesson.get('narration')
        report = dict(id=lesson['id'], revision=lesson['revision'], premiumNarration='absent', segmentCount=0,
                      audioBytes=0, measuredNarrationMilliseconds=0, errors=[], cueWarnings=[])
        if bundle is not None:
            expected = scripts(lesson); segments = bundle.get('segments', []) if isinstance(bundle, dict) else []
            if not isinstance(segments, list) or not all(isinstance(s, dict) and isinstance(s.get('id'), str) for s in segments): segments = []
            report['segmentCount'] = len(segments); errors = report['errors']
            if not isinstance(bundle, dict) or bundle.get('schemaVersion') != 1: errors.append('Unsupported narration schema.')
            ids = [s.get('id') for s in segments]
            if len(ids) != len(set(ids)): errors.append('Duplicate segment IDs.')
            wanted = {s['id'] for s in expected}
            errors += ['Missing segment: ' + x for x in sorted(wanted - set(ids))]
            errors += ['Unknown segment: ' + str(x) for x in set(ids) - wanted]
            durations = {}; used = set()
            for e in expected:
                s = next((s for s in segments if s.get('id') == e['id']), None)
                if s is None: continue
                if s.get('role') != e['role'] or s.get('scriptSHA256') != e['scriptSHA256']: errors.append('Stale script/role: ' + e['id'])
                key = s.get('assetID')
                if not isinstance(key, str):
                    errors.append('Invalid asset ID: ' + e['id']); continue
                used.add(key)
                if key not in decoded: errors.append(f"{e['id']}: {asset_errors.get(key, 'Missing MP3 asset.')}"); continue
                duration, _ = decoded[key]; durations[e['id']] = duration
                if s.get('durationMilliseconds') != assets[key]['durationMilliseconds']: errors.append('Duration mismatch: ' + e['id'])
                if not valid_cues(s.get('cues'), e['text'], s.get('durationMilliseconds', 0)): report['cueWarnings'].append('Ignored invalid cues: ' + e['id'])
            report['audioBytes'] = sum(decoded[k][1] for k in used if k in decoded)
            report['measuredNarrationMilliseconds'] = sum(durations.values())
            # Interactive worst path, not the sum of mutually exclusive branches.
            core = sum(durations.get('page:' + p['id'], 0) for p in lesson['pages'])
            for q in lesson['questions']:
                core += durations.get('question:' + q['id'], 0) + max((durations.get(f"feedback:{q['id']}:{c['id']}", 0) for c in q['choices']), default=0)
            core += max((durations.get('completion:' + str(n), 0) for n in range(len(lesson['questions']) + 1)), default=0)
            report['measuredCoreSeconds'] = core / 1000 + max(0, len(lesson['pages']) - 1) * 2 + len(lesson['questions']) * 20
            report['provenance'] = bundle.get('provenance') if isinstance(bundle, dict) else None
            if total > TOTAL_BYTES: errors.append('Total audio exceeds 40 MiB.')
            report['premiumNarration'] = 'invalid' if errors else 'complete'
        reports.append(report)
    return dict(decodedAudioBytes=total, assetErrors=asset_errors, ideas=reports)
