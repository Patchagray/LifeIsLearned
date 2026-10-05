"""Prepare the shortened revision-2 demo as an explicit update; never rewrite the startup seed."""
import argparse
import copy
import json
from pathlib import Path
from lesson_timing import plan, package_report, planning_errors
from validate_package import content

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / 'LifeIsLearned/Resources/starter.json'


def shortened_demo():
    package = copy.deepcopy(json.loads(SEED.read_text()))
    lesson = package['book']['lessons'][0]
    originals = {p['id']: p for p in lesson['pages']}
    specs = [
        ('welcome', 'The Prior Problem',
         'Existing beliefs can shape what we notice. This introductory lesson draws on reviewed material about priors, not the whole book. Malik, Elena, their college, and the report in this example are fictional.'),
        ('before', 'Before the report',
         'Malik wanted to keep the college work-study program. His job had helped him pay for transport and build confidence. Elena wanted fewer student jobs: her friend had taken extra shifts and fallen behind in class.\n\nBefore opening the report, each already had a picture of what working during college meant.'),
        ('same', 'One report. Two readings.',
         'The report described useful skills alongside fatigue and missed study time. It could not establish what caused those outcomes.\n\nMalik pointed to the benefits. Elena pointed to the problems. Each finding was on the page, but each student favored the part that matched an existing belief. More quotations only hardened their disagreement.'),
        ('revise', 'A better question',
         'Their adviser asked, “What finding would make you reconsider?”\n\nMalik realized he had collected support, not looked for challenges. Elena recognized the same habit. They agreed to examine both benefits and costs, including workload differences. Understanding each other’s experiences helped them discuss the evidence. It did not prove the program worked, or guarantee they would agree.'),
        ('distinction', 'Belief or bias?',
         'A prior is a belief held before new information arrives. Confirmation bias favors information that fits an existing view. Experience can be useful; unequal scrutiny is the problem. The adviser’s question is our teaching example, not a research-tested guarantee of persuasion.'),
        ('takeaway', 'Test your starting point',
         'Name your belief. Ask what evidence could change it. Examine credible support and challenges with equal care. Shared goals can help discussion; they cannot decide what is true.')
    ]
    lesson['pages'] = []
    for page_id, title, text in specs:
        page = copy.deepcopy(originals[page_id])
        page.update(title=title, text=text)
        lesson['pages'].append(page)
    lesson['questions'] = [
        dict(id='recognition', prompt='A manager expects remote work to fail. She dismisses credible benefits but accepts weak criticism. What is the problem?', correctChoiceID='selective', choices=[
            dict(id='selective', text='Unequal scrutiny that favors her existing belief.', feedback='Exactly: evidence quality should matter on both sides. An initial belief alone is not the problem.'),
            dict(id='certain', text='The report proves remote work fails.', feedback='That conclusion needs evidence. Selective scrutiny cannot establish whether remote work succeeds or fails.'),
            dict(id='badprior', text='Having any belief before reading.', feedback='Experience can inform a prior. The problem is favoring agreement over evidence quality.')]),
        dict(id='transfer', prompt='You favor tutoring; your friend doubts it. What would help you evaluate a new study fairly?', correctChoiceID='test', choices=[
            dict(id='pile', text='Collect only success stories.', feedback='Selecting only support repeats the bias. Examine credible challenges too.'),
            dict(id='agree', text='Treat a shared goal as proof.', feedback='A shared goal may help discussion, but cannot show whether tutoring works.'),
            dict(id='test', text='Agree what findings would change either view.', feedback='Explicit standards help you assess support and challenges consistently. They structure evaluation without guaranteeing agreement.')])
    ]
    lesson['revision'] = 2
    lesson['scopeNote'] = 'One introductory distinction: prior beliefs versus biased treatment of new evidence. The college, report and adviser are original fiction. The adviser’s question is a teaching strategy, not a tested persuasion result. This is not a complete chapter or book summary.'
    lesson['estimatedMinutes'] = plan(lesson)['approximateMinutes']
    package['collectionRevision'] = 2
    package['manifest'] = [dict(id=lesson['id'], revision=lesson['revision'])]
    package['removedLessonIDs'] = []
    package['book']['coverageNote'] = 'One selected introductory idea, not an exhaustive summary or the author’s ranking. Based on the previously reviewed publisher prologue and separately identified 2019 paper. The full book and Chapter 1 were not reviewed. This shortened demo does not establish coverage of the rest of the book.'
    content(package)
    errors = planning_errors(package, package_report(package))
    if errors:
        raise ValueError('\n'.join(errors))
    return package


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path, nargs='?', default=ROOT/'Example-Lesson-Package.json')
    parser.add_argument('--replace', action='store_true', help='Replace this explicitly selected review/export file, never the frozen seed.')
    args = parser.parse_args()
    if args.destination.resolve() == SEED.resolve():
        parser.error('The revision-1 startup seed is frozen. Export a reviewed full-collection update instead.')
    if args.destination.exists() and not args.replace:
        parser.error('Choose a new destination or explicitly use --replace for the review file.')
    package = shortened_demo()
    args.destination.write_text(json.dumps(package, ensure_ascii=False, indent=2)+'\n')
    timing = plan(package['book']['lessons'][0])
    print(f"Short demo review candidate: {timing['spokenWords']} spoken words; {timing['estimatedTotalSeconds']:.2f}s planned including pauses and answers. Premium-voice measurement is a separate release gate.")
