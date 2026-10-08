# Sound Production (phase four)

Research → Authoring → Illustration/Packaging → Sound Production.

Start with a reviewed complete book JSON. Audio is optional formatVersion 2 presentation data; never edit lesson wording to match a recording. Guide and Storyteller are production roles. Audition and obtain reviewer approval for voices from the connected ElevenLabs workspace, then keep the approved IDs stable across the batch. The iOS app only plays downloaded packaged files; it never accesses ElevenLabs or credentials.

## Export, produce, normalize, package

```sh
python3 Tools/export_narration_scripts.py reviewed-book.json narration-scripts.json
```

The deterministic manifest lists book/idea revisions, exact text, role, segment ID, UTF-8 SHA-256 and a safe hashed `.mp3` filename for every page, prompt, possible feedback response and 0/2–2/2 completion. These strings share constructors with `Tools/lesson_timing.py` and mirror `LessonNarration` exactly. A native/Python parity fixture is included in the evidence.

Use the connected ElevenLabs Sound Production workflow to generate each script with its approved role voice/model. Download the chosen masters once. Keep masters outside the app and public source repository. Credentials never belong in packages, manifests or provenance. Generation is a production action; it is not invoked by any of these packaging commands.

Install FFmpeg for local audio work (or set `LIL_FFMPEG` to an existing executable). Normalize each chosen master to its manifest filename in a separate `normalized/` directory:

```sh
python3 Tools/normalize_narration.py master.wav normalized/<manifest-file>.mp3 --report qa/<manifest-file>.json
```

The two-pass normalizer targets -16 LUFS integrated, -1.5 dBTP, mono 44.1 kHz and 64 kbps MP3, removing input metadata. Keep reports outside the clip directory. Audition both roles together, check encoder peaks/loudness and listen for clipping, wrong text, pronunciation or synthetic delivery. Automation cannot establish voice age/timbre or factual/script fidelity of the audible recording.

```sh
python3 Tools/package_narration.py reviewed-book.json narration-scripts.json normalized narrated-book.json \
  --collection-revision 3 --provenance approved-voices.json
python3 Tools/validate_package.py narrated-book.json --audio-gate --report audio-qa.json
```

Use the appropriate next collection revision, always greater than the input release. The packager preserves all idea revisions and semantic content. Every required filename must exist exactly once; unknown/missing files, changed script manifests, invalid MP3s, stereo, mismatched duration and budgets fail. It writes a separate complete output atomically and never overwrites the reviewed source.

Optional `--cues cues.json` maps manifest filenames to arrays of `{characterStart, characterLength, startMilliseconds, endMilliseconds}`. Coordinates are **UTF-16 code units**, including title and punctuation in the full exact spoken script. Use valid nonoverlapping ordered spans within the measured duration. Missing entries derive deterministic sentence/word-weighted coarse cues from decoded duration. These are estimated alignment; manually inspect Story following. An explicit null permits no cues.

Optional provenance keys: `provider` (elevenlabs), `modelID`, `guideVoiceID`, `guideVoiceName`, `storytellerVoiceID`, `storytellerVoiceName`, `producedAt`. `producedAt`, when supplied, is seconds since 2001-01-01 UTC to match this app's existing native Codable date convention. Omit unknown values. Never invent remembered IDs or include credentials.

## Gates and reports

- Existing structural, six-stage/five-primary-art, fiction/source, question and ≤300-second planning rules remain. `--audio-gate` additionally requires complete valid packaged narration for every idea and a measured worst-branch core at most 300 seconds (all pages/prompts, longest measured feedback per question, longest completion, 2-second page pauses and 40-second answers). All-branch audio duration is reported separately and is not the learner's linear core duration.
- With no `--audio-gate`, absent audio is valid and the report says absent. Invalid optional bundles report invalid and use local fallback in the app; resource abuse still fails import. Corrupt audio never grants premium mode. Missing/invalid cues alone only remove highlighting.
- Keep the 64 MiB **encoded JSON** limit after base64 expansion. MP3: at most 2 MiB each, 40 MiB decoded total, positive duration up to 600 seconds, full successful mono MPEG Layer III decode. Images retain their separate 24 MiB budget. Twelve ideas is a ceiling; optimize content/art/audio or curate fewer ideas to meet the total package budget.
- The existing `--approve-release` local premium-voice measurement path remains available for fallback releases. `--audio-gate` is packaged-audio QA, not reviewer/editorial/voice approval. Keep the script-bound measured report with the final package and obtain reviewer release approval.
- Narration-only changes require a collection revision, not an idea revision. Prose, questions, feedback, art, sources and Dive Deeper retain their existing semantic revision rules. Regenerate script hashes/audio when wording changes.

Publish approved JSON/thumbnail assets only through the existing reviewer-controlled release process. Remote package byte counts and SHA-256 cover audio naturally. Installed audio works offline and is reclaimed with the whole book.
