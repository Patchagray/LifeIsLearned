"""Future publication transaction guard: compare the next allowlist to origin/main.
Run before committing an approval/registry update; no network or mutation here.
"""
import json
from pathlib import Path
from publication_preflight import CANONICAL_IDS

def validate_update(previous, proposed):
    for registry in (previous,proposed):
        if registry.get('schemaVersion')!=1 or not isinstance(registry.get('entries'),list):raise ValueError('Invalid allowlist')
        ids=[e['bookID'] for e in registry['entries']]
        if len(ids)!=len(set(ids)) or not set(ids)<=CANONICAL_IDS:raise ValueError('Unapproved or duplicate identity')
    old={e['bookID']:e for e in previous['entries']};new={e['bookID']:e for e in proposed['entries']}
    if not set(old)<=set(new):raise ValueError('Removing releases requires a separate explicit revocation procedure')
    for key,e in new.items():
        if key not in old:continue
        before=old[key]
        if e==before:continue
        if type(e.get('collectionRevision')) is not int or e['collectionRevision']<=before['collectionRevision']:raise ValueError('A changed release requires a strictly newer collection revision')
        if e.get('approvalRecord')==before.get('approvalRecord'):raise ValueError('Changed bytes/revision require fresh owner approval')
    return proposed

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('previous',type=Path);p.add_argument('proposed',type=Path);a=p.parse_args()
    validate_update(json.loads(a.previous.read_text()),json.loads(a.proposed.read_text()));print('Registry update is monotonic; package/audio/owner gates still required.')
