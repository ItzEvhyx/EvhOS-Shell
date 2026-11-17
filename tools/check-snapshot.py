#!/usr/bin/env python3
"""Check captured files, permissions, secrets and referenced wallpaper assets."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('capture_live', ROOT/'tools/capture-live.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def check(update=False):
    actual = capture.manifest(ROOT)
    for name in actual:
        path = ROOT/name
        if not path.is_symlink():
            data = path.read_bytes()
            capture.scan_text(data, Path(name))
            if path.suffix == '.py':
                compile(data, name, 'exec')
    metadata = json.loads((ROOT/'snapshot/metadata.json').read_text())
    prefix = metadata['source_home'].rstrip('/')+'/'
    def media(value):
        if isinstance(value, str) and value.startswith(prefix+'Pictures/Wallpapers/'):
            if not (ROOT/'snapshot/home'/value[len(prefix):]).exists():
                raise ValueError('Unbundled wallpaper reference: '+value)
        elif isinstance(value, dict):
            for item in value.values():
                media(item)
        elif isinstance(value, list):
            for item in value:
                media(item)
    for path in (ROOT/'snapshot/home/.local/state/serpantinum/desktop-presets').glob('*.json'):
        media(json.loads(path.read_text()))
    for path in (ROOT/'snapshot/home/.cache/serpantinum/wallpaper').glob('current_*'):
        if path.is_file() and path.stat().st_size < 4096 and path.suffix not in ('.json', '.png'):
            media(path.read_text().strip())
    path = ROOT/'snapshot/manifest.json'
    if update:
        path.write_text(json.dumps(actual, indent=2)+'\n')
    expected = json.loads(path.read_text())
    differences = [name for name in sorted(set(expected)|set(actual)) if expected.get(name) != actual.get(name)]
    if differences:
        raise ValueError('Snapshot manifest differs:\n'+'\n'.join(differences))
    print(f'Snapshot verified: {len(actual)} files/links; captured media references resolve.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update', action='store_true', help='reviewed source edits: regenerate checksums before testing')
    args = parser.parse_args()
    check(args.update)
