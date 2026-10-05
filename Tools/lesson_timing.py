"""Whole-idea planning and release gates; never a runtime playback deadline."""
import math
import re

WORDS_PER_MINUTE = 130
PAGE_PAUSE_SECONDS = 2
ANSWER_SECONDS = 20
MAX_SECONDS = 300


def word_count(text):
    # Same Unicode letters/numbers and internal apostrophes as LessonTiming.swift.
    return len(re.findall(r"[^\W_]+(?:['’][^\W_]+)*", text))


def feedback(choice, correct):
    return ("That's right. " if correct else "Let's reconsider. ") + choice['feedback']


def narration_segments(lesson):
    segments = [dict(id='page:' + p['id'], kind=p['kind'], role=p['role'],
                     text=p['title'] + '. ' + p['text']) for p in lesson['pages']]
    for q in lesson['questions']:
        text = q['prompt'] + '\n' + '\n'.join(
            f"Option {i + 1}. {c['text']}" for i, c in enumerate(q['choices']))
        segments.append(dict(id='question:' + q['id'], kind='question', role='guide', text=text))
        responses = [feedback(c, c['id'] == q['correctChoiceID']) for c in q['choices']]
        segments.append(dict(id='feedback:' + q['id'], kind='feedback', role='guide',
                             text=max(responses, key=word_count)))
    n = len(lesson['questions'])
    segments.append(dict(id='completion', kind='completion', role='guide',
                         text=f"Lesson complete. You've practiced a new idea. {n} of {n} correct on the first try."))
    return segments


def plan(lesson):
    segments = narration_segments(lesson)
    for s in segments:
        s['words'] = word_count(s['text'])
    words = sum(s['words'] for s in segments)
    transitions = max(0, len(lesson['pages']) - 1)
    speech = words * 60 / WORDS_PER_MINUTE
    pauses = transitions * PAGE_PAUSE_SECONDS
    answers = len(lesson['questions']) * ANSWER_SECONDS
    total = speech + pauses + answers
    return dict(id=lesson['id'], revision=lesson['revision'], spokenWords=words,
                wordsByKind={k: sum(s['words'] for s in segments if s['kind'] == k)
                             for k in sorted({s['kind'] for s in segments})},
                wordsByRole={role: sum(s['words'] for s in segments if s['role'] == role)
                             for role in ('guide', 'storyteller')},
                wordsPerMinute=WORDS_PER_MINUTE, transitionCount=transitions,
                pagePauseSeconds=PAGE_PAUSE_SECONDS, pauseSeconds=pauses,
                answerAllowanceSeconds=answers, estimatedSpeechSeconds=speech,
                estimatedTotalSeconds=total, approximateMinutes=math.ceil(total / 60),
                planningPass=total <= MAX_SECONDS, measurementStatus='pending-premium-voices',
                segments=segments)


def package_report(package):
    return dict(bookID=package['book']['id'], collectionRevision=package['collectionRevision'],
                method='word-count planning estimate; not measured playback',
                prefaceNarrated=False, sourcesAndInterfaceNarrated=False,
                feedbackPolicy='Longest single response per question, including its spoken prefix; retries excluded.',
                ideas=[plan(lesson) for lesson in package['book']['lessons']])


def planning_errors(package, report):
    errors = []
    for lesson, idea in zip(package['book']['lessons'], report['ideas']):
        if len(lesson['questions']) != 2:
            errors.append(f"{lesson['id']}: authored releases require exactly two application questions.")
        if not idea['planningPass']:
            errors.append(f"{lesson['id']}: {idea['estimatedTotalSeconds']:.2f} seconds exceeds the 300-second whole-idea budget. Shorten the content; do not speed up playback.")
        if lesson['estimatedMinutes'] != idea['approximateMinutes']:
            errors.append(f"{lesson['id']}: estimatedMinutes must be {idea['approximateMinutes']} for the reference whole-idea plan.")
    return errors


def apply_measurements(report, measurements):
    """Bind observed durations to the exact script, revision and premium settings."""
    errors = []
    reference = measurements.get('reference', {})
    if reference.get('speed') != 1 or reference.get('pagePauseSeconds') != PAGE_PAUSE_SECONDS:
        errors.append('Measure at normal speed (1) with the fresh-install 2-second page pause.')
    for role in ('guide', 'storyteller'):
        voice = reference.get(role, {})
        if not voice.get('identifier') or not voice.get('name') or voice.get('quality') != 'premium':
            errors.append(f'{role}: record the actual installed premium voice identifier, name and quality.')
    if measurements.get('bookID') != report['bookID'] or measurements.get('collectionRevision') != report['collectionRevision']:
        errors.append('Measurements belong to a different book or collection revision.')
    if measurements.get('method') != 'speech-completion-callbacks':
        errors.append('Record speech-completion callback durations, not word-count estimates.')
    if not reference.get('deviceModel') or not reference.get('os'):
        errors.append('Record the actual device model and operating system.')
    observed = measurements.get('ideas', [])
    if len(observed) != len(report['ideas']):
        errors.append('Supply one timing observation for every selected idea.')
    for idea in report['ideas']:
        matches = [m for m in observed if m.get('id') == idea['id'] and m.get('revision') == idea['revision']]
        if len(matches) != 1:
            errors.append(f"{idea['id']}: missing or duplicate measured idea/revision.")
            continue
        measured = matches[0].get('segments', [])
        expected = idea['segments']
        if len(measured) != len(expected) or any(
            any(actual.get(k) != wanted[k] for k in ('id', 'role', 'text'))
            for actual, wanted in zip(measured, expected)
        ):
            errors.append(f"{idea['id']}: measured script differs from the complete reference narration.")
            continue
        seconds = [s.get('seconds') for s in measured]
        if not all(type(t) in (int, float) and math.isfinite(t) and t > 0 for t in seconds):
            errors.append(f"{idea['id']}: every segment requires a positive measured duration.")
            continue
        speech = sum(seconds)
        total = speech + idea['pauseSeconds'] + idea['answerAllowanceSeconds']
        idea.update(measuredSpeechSeconds=speech, measuredTotalSeconds=total,
                    measurementStatus='passed' if total <= MAX_SECONDS else 'over-budget')
        if total > MAX_SECONDS:
            errors.append(f"{idea['id']}: measured total {total:.2f} seconds exceeds 300 seconds.")
    report['referenceVoices'] = reference
    return errors
