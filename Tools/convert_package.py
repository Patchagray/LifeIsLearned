"""Convert a reviewed legacy collection to v2. macOS sips optimizes shared artwork."""
import argparse, base64, copy, hashlib, json, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def optimize(raw):
    with tempfile.TemporaryDirectory() as temp:
        source, target = Path(temp)/'input', Path(temp)/'art.jpg'
        source.write_bytes(raw)
        subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','82','--resampleHeightWidthMax','1440',str(source),'--out',str(target)], check=True, capture_output=True)
        data = target.read_bytes()
        if len(data) > 2*1024*1024:
            raise ValueError('Artwork still exceeds 2 MiB. Optimize the source before conversion.')
        return data

def convert(package, revision=1):
    result = copy.deepcopy(package)
    assets = {}; seen = {}
    for lesson in result['book']['lessons']:
        for page in lesson['pages']:
            raw = None
            if page.get('imageBase64'): raw = base64.b64decode(page['imageBase64'], validate=True)
            elif page.get('imageAsset'):
                folder=ROOT/'LifeIsLearned/Resources/Assets.xcassets'/(page['imageAsset']+'.imageset')
                meta=json.loads((folder/'Contents.json').read_text())
                raw=(folder/meta['images'][0]['filename']).read_bytes()
            if raw:
                digest=hashlib.sha256(raw).hexdigest()
                if digest not in seen:
                    asset_id='art-'+digest[:16]; seen[digest]=asset_id
                    assets[asset_id]={'mediaType':'image/jpeg','data':base64.b64encode(optimize(raw)).decode()}
                page['imageID']=seen[digest]
            page.pop('imageAsset',None);page.pop('imageBase64',None)
    result.update(formatVersion=2,collectionRevision=revision,fullCollection=True,
                  manifest=[{'id':l['id'],'revision':l['revision']} for l in result['book']['lessons']],
                  removedLessonIDs=[],assets=assets)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('destination',type=Path)
    parser.add_argument('--collection-revision',required=True,type=int)
    parser.add_argument('--reviewed-full-collection',required=True,action='store_true',help='Confirm this is the entire prepared and reviewed release, not an idea patch.')
    args=parser.parse_args()
    if args.collection_revision<1: parser.error('Use a positive collection revision.')
    if args.destination.exists(): parser.error('Choose a new output path to preserve the original.')
    package=json.loads(args.source.read_text())
    if package.get('formatVersion')!=1: parser.error('This conversion is for formatVersion 1 only.')
    result=convert(package,args.collection_revision)
    args.destination.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Converted complete collection. Review revisions, coverage, answer keys and removals before importing.')
