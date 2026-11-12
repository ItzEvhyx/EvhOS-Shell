#!/usr/bin/env python3
"""Prototype for capturing EvhOS visual settings; does not apply themes."""
import argparse
import json
import re
from pathlib import Path

SECTIONS = ('theme', 'bar', 'dock')
MONITOR = re.compile(r'^[A-Za-z0-9_-]+$')

def capture(home):
    settings = json.loads((home / '.config/serpantinum/settings.json').read_text())
    result = {'version': 1, 'settings': {k: settings[k] for k in SECTIONS if k in settings}, 'widgets': {}, 'wallpapers': {}}
    widgets = home / '.local/state/serpantinum/widgets'
    if widgets.exists():
        for p in sorted(widgets.glob('*/layout.json')):
            if MONITOR.fullmatch(p.parent.name):
                result['widgets'][p.parent.name] = json.loads(p.read_text())
    wallpaper = home / '.cache/serpantinum/wallpaper'
    if wallpaper.exists():
        for p in sorted(wallpaper.glob('current_*')):
            monitor = p.name[len('current_'):]
            if MONITOR.fullmatch(monitor) and not monitor.endswith('_name') and not monitor.startswith('wallpaper') and p.is_file():
                path = p.read_text().strip()
                if path.startswith('/'):
                    result['wallpapers'][monitor] = path
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = capture(args.home)
    args.output.write_text(json.dumps(data, indent=2) + '\n')

if __name__ == '__main__':
    main()
