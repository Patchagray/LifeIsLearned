"""Portable content/project checks; intentionally not a substitute for xcodebuild."""
import base64,json,re,struct,xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(value,message):
    assert value,message
    checks.append(message)
def unique(items):return len(items)==len(set(items)) and all(items)
def content(package):
    check(package['formatVersion']==1,'Package format version is supported')
    b=package['book'];sources=b['sources']
    check(bool(b['id']) and bool(b['title']) and bool(b['author']) and bool(b['coverageNote']),'Book metadata and coverage note present')
    check(unique([s['id'] for s in sources]),'Source IDs unique')
    for s in sources:
        u=urlparse(s['url'])
        check(u.scheme=='https' and bool(u.netloc) and all(s[k] for k in ['title','locator','scope']),f'Source complete: {s["id"]}')
    check(unique([l['id'] for l in b['lessons']]),'Lesson IDs unique')
    known={s['id'] for s in sources}
    for lesson in b['lessons']:
        check(lesson['revision']>0 and lesson['estimatedMinutes']>0 and bool(lesson['scopeNote']),'Lesson revision, estimate, scope present')
        p=lesson['pages']; qs=lesson['questions']
        check(2<=len(p)<=40 and unique([x['id'] for x in p]),'Lesson screen IDs/count valid')
        check(p[0]['kind']=='intro' and p[-1]['kind']=='takeaway','Intro/takeaway boundaries correct')
        for page in p:
            check(page['kind'] in ['intro','story','explanation','takeaway'] and page['role'] in ['guide','storyteller'],f'Screen type and voice: {page["id"]}')
            check(page['title'] and 0<len(page['text'])<=6000,f'Screen text: {page["id"]}')
            check(set(page['sourceIDs'])<=known and (page['kind']=='story' or bool(page['sourceIDs'])),f'Source links: {page["id"]}')
            if page.get('imageAsset'):
                folder=ROOT/'LifeIsLearned/Resources/Assets.xcassets'/(page['imageAsset']+'.imageset')
                meta=json.loads((folder/'Contents.json').read_text())
                check((folder/meta['images'][0]['filename']).is_file() and page.get('imageDescription'),f'Illustration and accessibility: {page["id"]}')
        check(2<=len(qs)<=10 and unique([q['id'] for q in qs]),'Practice questions present with unique IDs')
        for q in qs:
            choices=q['choices']
            check(2<=len(choices)<=6 and unique([c['id'] for c in choices]) and q['correctChoiceID'] in [c['id'] for c in choices],f'Answer key: {q["id"]}')
            check(all(c['text'] and c['feedback'] for c in choices),f'Feedback for every answer: {q["id"]}')
    return sum(len((p['title']+' '+p['text']).split()) for l in b['lessons'] for p in l['pages'])

# Minimal OpenStep parser validates project syntax and every object reference.
def parse_pbx(text):
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

starter=json.loads((ROOT/'LifeIsLearned/Resources/starter.json').read_text())
words=content(starter)
check(starter==json.loads((ROOT/'Example-Lesson-Package.json').read_text()),'Importable example matches bundled content')
project=parse_pbx((ROOT/'LifeIsLearned.xcodeproj/project.pbxproj').read_text());objects=project['objects']
check(project['rootObject'] in objects,'Project root resolves')
for key,value in objects.items():
    def walk(item):
        if isinstance(item,dict):
            for v in item.values():walk(v)
        elif isinstance(item,list):
            for v in item:walk(v)
        elif isinstance(item,str) and re.fullmatch('[A-F0-9]{24}',item):
            assert item in objects,f'Dangling project reference: {item}'
    walk(value)
check(True,'Every Xcode object reference resolves')
root_obj=objects[project['rootObject']];resolved=[]
def visit(groupid,parent):
    group=objects[groupid]
    base=parent/group.get('path','')
    for childid in group.get('children',[]):
        child=objects[childid]
        if child['isa']=='PBXGroup':visit(childid,base)
        elif child['isa']=='PBXFileReference' and child.get('sourceTree')!='BUILT_PRODUCTS_DIR':
            path=base/child['path'];check(path.exists(),f'Project file exists: {path.relative_to(ROOT)}');resolved.append(path.resolve())
visit(root_obj['mainGroup'],ROOT)
expected={p.resolve() for p in (ROOT/'LifeIsLearned').rglob('*.swift')}|{p.resolve() for p in (ROOT/'Tests').glob('*.swift')}
check(expected<={p for p in resolved},'All app and test Swift files included in project')
for phase in objects.values():
    if phase['isa'] in ['PBXSourcesBuildPhase','PBXResourcesBuildPhase']:
        for b in phase['files']:
            ref=objects[objects[b]['fileRef']]
            check(ref['isa']=='PBXFileReference','Build phase references a real file')
scheme=ET.parse(ROOT/'LifeIsLearned.xcodeproj/xcshareddata/xcschemes/LifeIsLearned.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    check(ref.attrib['BlueprintIdentifier'] in objects,'Shared scheme target resolves')
check(len(scheme.findall('.//TestableReference'))==1,'Shared scheme includes XCTest target')
for img in (ROOT/'LifeIsLearned/Resources/Assets.xcassets').rglob('illustration.png'):
    raw=img.read_bytes();check(raw[:8]==b'\x89PNG\r\n\x1a\n','Illustration has PNG signature')
    w,h=struct.unpack('>II',raw[16:24]);check(w>0 and h>0,f'Illustration dimensions: {w}×{h}')
check(len(list((ROOT/'LifeIsLearned/Resources/Assets.xcassets').rglob('illustration.png')))==3,'Three scene illustrations bundled')
report=f'''# Validation report\n\nPortable checks passed: **{len(checks)}**.\n\n- Starter content: {len(starter['book']['lessons'][0]['pages'])} screens, {words} narrated words, two practice questions, complete per-answer feedback.\n- Source IDs, scopes, coverage notes, page boundaries, answer keys and illustration descriptions checked.\n- Bundled and importable example content match.\n- OpenStep Xcode project parsed; all object/file references resolve and all Swift files are included.\n- Shared scheme XML parsed; app and XCTest targets resolve.\n- Three valid PNG assets packaged with asset-catalog metadata.\n\n**Not executed in this Linux environment:** Swift compilation, Xcode build, XCTest execution, simulator UI checks, hardware speech checks. The portable checks do not prove the app compiles or that playback works on iOS.\n\nThe next step is the Mac-side build/test pass in CODEX_HANDOFF.md.\n'''
(ROOT/'VALIDATION.md').write_text(report)
print(report)
