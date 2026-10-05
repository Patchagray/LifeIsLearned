"""Place the short-demo acceptance fixture in a booted simulator's Files provider."""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('device', help='Installed simulator UDID; this tool never targets a physical device.')
args = parser.parse_args()
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))
device = next((d for group in devices['devices'].values() for d in group if d['udid'] == args.device), None)
if device is None or device['state'] != 'Booted':
    parser.error('Boot the selected simulator in Xcode/Simulator first, then run this command again.')
groups = subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.apple.DocumentsApp', 'groups'], text=True)
mapping = dict(line.split('\t', 1) for line in groups.splitlines() if '\t' in line)
root = mapping.get('group.com.apple.FileProvider.LocalStorage')
if root is None:
    parser.error('The simulator Files provider is unavailable. Open Files once, then retry.')
storage = Path(root)/'File Provider Storage'
if not storage.is_dir():
    parser.error('The simulator Files storage is unavailable. Open Files once, then retry.')
destination = storage/'Handoff003-ShortDemo.json'
data = (ROOT/'Example-Lesson-Package.json').read_bytes()
if destination.exists() and destination.read_bytes() != data:
    parser.error('A different fixture already exists. Preserve it and choose a fresh test simulator.')
if not destination.exists():
    with destination.open('xb') as stream:
        stream.write(data)
print(f'Prepared Handoff003-ShortDemo.json in {device["name"]} Files. No app library or progress was changed.')
