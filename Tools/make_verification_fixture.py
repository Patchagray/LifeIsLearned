"""Generate a clearly labeled synthetic collection for import/layout checks, never new book content."""
import argparse,copy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('destination',type=Path)
parser.add_argument('--largest',action='store_true',help='100 ideas, 40 pages each, 32 shared assets; stays inside format-2 limits')
args=parser.parse_args()
if args.destination.exists():parser.error('Choose a new output path; existing files are preserved')
p=json.loads((ROOT/'LifeIsLearned/Resources/starter.json').read_text())
p['book'].update(id='verification-collection',title='The Art of Paying Attention',author='Interface verification fixture',isDemo=True,
                 coverageNote='Synthetic verification collection. Repeats the reviewed starter to exercise import ordering, shared artwork and interface states; not a new book summary.')
seed=copy.deepcopy(p['book']['lessons'][0]);count=100 if args.largest else 3
if args.largest:
    image=p['assets'][sorted(p['assets'])[0]]
    p['assets']={f'shared-{i}':image for i in range(32)}
lessons=[]
for number in range(1,count+1):
    lesson=copy.deepcopy(seed);lesson.update(id=f'fixture-{number}',title=f'A different point of view · {number}')
    if args.largest:
        lesson['pages']=[]
        for j in range(40):
            page=copy.deepcopy(seed['pages'][0 if j==0 else -1 if j==39 else 1])
            page.update(id=f'page-{j}',imageID=f'shared-{j%32}',imageDescription='Original starter illustration reused for verification')
            lesson['pages'].append(page)
    lessons.append(lesson)
p['book']['lessons']=lessons;p['manifest']=[{'id':l['id'],'revision':l['revision']} for l in lessons]
args.destination.write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {count} synthetic ideas to {args.destination}; validate before importing.')
