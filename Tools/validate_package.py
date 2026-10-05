"""Read-only portable validation of whole collections. Native image decoding is checked by the app."""
import argparse,base64,json,re,struct,sys,xml.etree.ElementTree as ET
from lesson_timing import package_report, planning_errors, apply_measurements
from pathlib import Path
from urllib.parse import urlparse
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(value,message):
    if not value: raise ValueError(message)
    checks.append(message)
def clean(value):return isinstance(value,str) and bool(value.strip())
def unique(items):return len(items)==len(set(items)) and all(clean(i) for i in items)
def dimensions(raw):
    if raw[:8]==b'\x89PNG\r\n\x1a\n': return 'image/png',struct.unpack('>II',raw[16:24])
    if raw[:2]==b'\xff\xd8':
        i=2
        while i<len(raw):
            if raw[i]!=255:i+=1;continue
            while i<len(raw) and raw[i]==255:i+=1
            marker=raw[i];i+=1
            if marker in (0xd8,0xd9):continue
            length=int.from_bytes(raw[i:i+2],'big')
            if marker in (0xc0,0xc1,0xc2):
                return 'image/jpeg',(int.from_bytes(raw[i+5:i+7],'big'),int.from_bytes(raw[i+3:i+5],'big'))
            if length<2:break
            i+=length
    raise ValueError('Unreadable PNG/JPEG header')
def content(p):
    check(p['formatVersion']==2,'New imports require formatVersion 2; convert reviewed legacy collections first')
    check(type(p['collectionRevision']) is int and p['collectionRevision']>0,'Positive collectionRevision required')
    check(p['fullCollection'] is True,'Declare fullCollection: true')
    b=p['book'];lessons=b['lessons'];sources=b['sources'];assets=p.get('assets',{})
    check(all(clean(b[k]) for k in ['id','title','author','coverageNote']),'Book identity and coverage required')
    check(len(lessons)<=12,f'This collection contains {len(lessons)} ideas. Prepare a complete release with no more than 12 selected ideas.')
    check(bool(lessons) and unique([l['id'] for l in lessons]),'Provide 1–12 unique, nonempty idea IDs')
    check(p['manifest']==[{'id':l['id'],'revision':l['revision']} for l in lessons],'Ordered manifest must exactly match all ideas/revisions')
    removed=p.get('removedLessonIDs',[])
    check(unique(removed) and not set(removed)&{l['id'] for l in lessons},'Removed IDs must be unique and absent from the active manifest')
    check(unique(list(assets)),'Shared asset IDs must be unique and nonempty; resource budgets apply without a count limit')
    total=0
    for asset in assets.values():
        raw=base64.b64decode(asset['data'],validate=True);total+=len(raw)
        check(len(raw)<=2*1024*1024,'Each image must be at most 2 MiB')
        mime,(w,h)=dimensions(raw)
        check(asset['mediaType']==mime and 0<w<=2048 and 0<h<=2048,'Use PNG/JPEG with matching mediaType and dimensions at most 2048 × 2048')
    check(total<=24*1024*1024,'Total decoded image bytes must be at most 24 MiB')
    if b.get('coverAssetID'):check(b['coverAssetID'] in assets and clean(b.get('coverDescription')),'Cover asset and accessible description required')
    check(bool(sources) and unique([s['id'] for s in sources]),'Source IDs must be unique')
    for source in sources:
        url=urlparse(source['url'])
        check(url.scheme=='https' and bool(url.netloc) and all(clean(source[k]) for k in ['title','locator','scope']),'Source title, HTTPS URL, locator and scope required')
    known={s['id'] for s in sources}
    for lesson in lessons:
        check(type(lesson['revision']) is int and lesson['revision']>0 and lesson['estimatedMinutes']>0 and clean(lesson['title']) and clean(lesson['scopeNote']),'Idea title, revision, estimate and scope required')
        pages=lesson['pages'];questions=lesson['questions']
        check(2<=len(pages)<=40 and unique([x['id'] for x in pages]),'Use 2–40 unique screens')
        check(pages[0]['kind']=='intro' and pages[-1]['kind']=='takeaway','Begin with intro and end with takeaway')
        for page in pages:
            check(page['kind'] in ['intro','story','explanation','takeaway'] and page['role'] in ['guide','storyteller'],'Valid screen kind and voice required')
            check(clean(page['title']) and clean(page['text']) and len(page['text'])<=6000,'Screen needs title and 1–6000 text characters')
            check(set(page['sourceIDs'])<=known and (page['kind']=='story' or bool(page['sourceIDs'])),'Teaching screens need valid source references')
            check(not page.get('imageAsset') and not page.get('imageBase64'),'Format 2 uses shared imageID references')
            if page.get('imageID'):check(page['imageID'] in assets and clean(page.get('imageDescription')),'Image ID and accessible description required')
        check(2<=len(questions)<=10 and unique([q['id'] for q in questions]),'Use 2–10 unique questions')
        for question in questions:
            choices=question['choices']
            check(clean(question['prompt']) and 2<=len(choices)<=6 and unique([c['id'] for c in choices]),'Question prompt and unique choices required')
            check(question['correctChoiceID'] in [c['id'] for c in choices] and all(clean(c['text']) and clean(c['feedback']) for c in choices),'Correct answer and explanatory feedback required')
    return len(lessons)
# Minimal OpenStep parser validates project syntax and every object reference.
def parse_pbx(text):
    text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
    text=re.sub(r'//[^\n]*','',text)
    tokens=re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+',text)
    pos=0
    def take(expected=None):
        nonlocal pos
        t=tokens[pos];pos+=1
        if expected: assert t==expected,(t,expected)
        return t
    def value():
        t=take()
        if t=='{':
            d={}
            while tokens[pos]!='}':
                key=take();key=json.loads(key) if key.startswith('"') else key
                take('=');d[key]=value();take(';')
            take('}');return d
        if t=='(':
            items=[]
            while tokens[pos]!=')':
                items.append(value())
                if tokens[pos]==',':take(',')
                else:break
            take(')');return items
        return json.loads(t) if t.startswith('"') else t
    result=value();assert pos==len(tokens)
    return result


def validate_project():
    project=parse_pbx((ROOT/'LifeIsLearned.xcodeproj/project.pbxproj').read_text());objects=project['objects']
    check(project['rootObject'] in objects,'Project root resolves')
    def walk(item):
        if isinstance(item,dict):
            for value in item.values():walk(value)
        elif isinstance(item,list):
            for value in item:walk(value)
        elif isinstance(item,str) and re.fullmatch('[A-F0-9]{24}',item):check(item in objects,'Project reference resolves: '+item)
    for obj in objects.values():walk(obj)
    resolved=[]
    def visit(groupid,parent):
        group=objects[groupid];base=parent/group.get('path','')
        for childid in group.get('children',[]):
            child=objects[childid]
            if child['isa']=='PBXGroup':visit(childid,base)
            elif child['isa']=='PBXFileReference' and child.get('sourceTree')!='BUILT_PRODUCTS_DIR':
                path=base/child['path'];check(path.exists(),'Project file exists: '+str(path.relative_to(ROOT)));resolved.append(path.resolve())
    visit(objects[project['rootObject']]['mainGroup'],ROOT)
    expected={p.resolve() for p in (ROOT/'LifeIsLearned').rglob('*.swift')}|{p.resolve() for p in (ROOT/'Tests').glob('*.swift')}|{p.resolve() for p in (ROOT/'UITests').glob('*.swift')}
    check(expected<=set(resolved),'All Swift sources and tests are in the project')
    scheme=ET.parse(ROOT/'LifeIsLearned.xcodeproj/xcshareddata/xcschemes/LifeIsLearned.xcscheme')
    for ref in scheme.findall('.//BuildableReference'):check(ref.attrib['BlueprintIdentifier'] in objects,'Shared scheme target resolves')
    check(len(scheme.findall('.//TestableReference'))==2,'Shared scheme includes unit and UI tests')

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON object key: {key}')
        result[key] = value
    return result


def read_package(path):
    check(path.stat().st_size <= 64*1024*1024, 'Package size at most 64 MiB before reading')
    data = path.read_bytes()
    check(len(data) <= 64*1024*1024, 'Package size at most 64 MiB')
    return json.loads(data, object_pairs_hook=unique_object), len(data)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages',type=Path,nargs='*')
    parser.add_argument('--report',type=Path)
    parser.add_argument('--authoring-gate',action='store_true',help='Fail over-budget plans, non-two-question releases and inconsistent whole-idea estimates.')
    parser.add_argument('--measurements',type=Path,help='Premium-voice speech-completion timing JSON for one collection.')
    parser.add_argument('--approve-release',action='store_true',help='Also require matching measured premium-voice timing at or below 300 seconds.')
    args=parser.parse_args()
    paths=args.packages or [ROOT/'LifeIsLearned/Resources/starter.json',ROOT/'Example-Lesson-Package.json']
    if args.measurements and len(paths)!=1:
        parser.error('Supply exactly one collection with --measurements.')
    results=[];errors=[]
    try:
        for path in paths:
            package,size=read_package(path);ideas=content(package)
            timing=package_report(package)
            if args.authoring_gate or args.approve_release:
                errors.extend(planning_errors(package,timing))
            if args.measurements:
                errors.extend(apply_measurements(timing,json.loads(args.measurements.read_text())))
            elif args.approve_release:
                errors.append('Release approval requires measured premium voices; a planning estimate alone is insufficient.')
            results.append(dict(file=path.name,bytes=size,ideas=ideas,assets=len(package.get('assets',{})),timing=timing))
        if not args.packages:
            validate_project()
    except (ValueError,KeyError,TypeError,IndexError,struct.error) as error:
        errors.append(str(error))
    report=dict(checksPassed=len(checks),packages=results,errors=errors,
                authoringGate='failed' if errors else 'passed' if args.authoring_gate or args.approve_release else 'not-requested',
                releaseApproval='approved' if args.approve_release and not errors else 'not-approved',
                scope='Portable structural/header checks and explicit planning estimates. Native decoding, compilation and measured playback are separate.')
    if args.report:args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    # Keep the terminal summary brief; detailed scripts and counts are in --report.
    print(json.dumps({k:v for k,v in report.items() if k!='packages'},indent=2))
    for result in results:
        for idea in result['timing']['ideas']:
            print(f"{result['file']} / {idea['id']}: {idea['spokenWords']} spoken words, {idea['estimatedTotalSeconds']:.2f}s planned, {idea['measurementStatus']}")
    return 1 if errors else 0


if __name__=='__main__':
    sys.exit(main())
