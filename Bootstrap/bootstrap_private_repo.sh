#!/usr/bin/env bash
# Owner-authorized bootstrap ONLY: creates empty private repo + canonical planned catalog.
# Does NOT publish any books, audio, covers or GitHub release assets.
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /path/to/LifeIsLearned-app-repo /path/to/empty-working-directory" >&2
  exit 2
fi
APP_ROOT="$(cd "$1" && pwd)"
WORK_DIR="$2"
FULL_REPO="Patchagray/LifeIsLearned-Published"
CANONICAL="$APP_ROOT/Catalog/Remote-Catalog-001.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD="$SCRIPT_DIR/../PrivateRepoScaffold"

for command in gh git python3; do
  command -v "$command" >/dev/null || { echo "Required command not available: $command" >&2; exit 3; }
done
[ -f "$CANONICAL" ] || { echo "Canonical Catalog 001 file missing: $CANONICAL" >&2; exit 3; }
[ -d "$SCAFFOLD" ] || { echo "Scaffold not found: $SCAFFOLD" >&2; exit 3; }
[ -d "$WORK_DIR" ] && [ -z "$(ls -A "$WORK_DIR")" ] || { echo "Working directory must be an existing, EMPTY directory." >&2; exit 3; }

# The source app metadata must be the 50 planned titles, NOT unapproved releases.
python3 - "$CANONICAL" <<'PY'
import json,sys
p=json.load(open(sys.argv[1],encoding='utf-8'))
assert p['schemaVersion']==1 and p['catalogID']=='catalog-001' and p['catalogRevision']==1
assert len(p['books'])==50 and len({b['id'] for b in p['books']})==50
assert all(b['availability']=='planned' and not b.get('package') and not b.get('thumbnail') for b in p['books'])
print('Validated canonical 50-title planned catalog (zero published packages).')
PY

gh auth status >/dev/null || { echo "GitHub CLI is not authenticated: sign in on your Mac/Codex environment first." >&2; exit 4; }
cd "$WORK_DIR"
if gh repo view "$FULL_REPO" --json isPrivate >/dev/null 2>&1; then
  echo "Repository name already exists; obtain an alternative from the owner." >&2
  exit 5
fi
gh repo create "$FULL_REPO" --private --description "Private approved Life Is Learned book distribution origin"
visibility="$(gh repo view "$FULL_REPO" --json isPrivate --jq .isPrivate)"
[ "$visibility" = "true" ] || { echo "FATAL: repository is not private; refusing initialization." >&2; exit 5; }

gh repo clone "$FULL_REPO" LifeIsLearned-Published
cd LifeIsLearned-Published
# This is a first-run bootstrap. Do not overwrite any pre-existing repository contents.
if [ -n "$(find . -maxdepth 1 -mindepth 1 ! -name .git -print -quit)" ]; then
  echo "Repository already contains files; aborting rather than modifying it." >&2
  exit 6
fi
cp -R "$SCAFFOLD"/. .
cp "$CANONICAL" catalog/Remote-Catalog-001.json
python3 - <<'PY'
import json
for n in ('approved-packages','approved-covers'):
  v=json.load(open('catalog/'+n+'.json'))
  assert v == {'schemaVersion':1,'entries':[]}
print('Verified both allowlists empty.')
PY

git symbolic-ref HEAD refs/heads/main
git add README.md .gitignore catalog/Remote-Catalog-001.json catalog/approved-packages.json catalog/approved-covers.json catalog/README.md covers/README.md approvals/README.md
git commit -m "Initialize private publication origin with 50 planned titles and zero releases"
git push -u origin main
[ "$(gh repo view "$FULL_REPO" --json isPrivate --jq .isPrivate)" = true ] || { echo "FATAL: privacy check failed after push." >&2; exit 7; }
echo "Created/initialized PRIVATE repo: $FULL_REPO"
echo "Book packages published: ZERO. Covers published: ZERO. Wait for separate owner's release approval."
