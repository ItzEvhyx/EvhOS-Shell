#!/usr/bin/env python3
"""Save and apply Serpantinum desktop arrangements without replacing other settings."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

NAME = re.compile(r'^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$')
MONITOR = re.compile(r'^[A-Za-z0-9_-]+$')
SECTIONS = ('theme', 'bar', 'dock')
HOME = Path.home()
STATE = Path(os.environ.get('QS_STATE_DIR') or HOME / '.local/state/serpantinum')
CACHE = Path(os.environ.get('QS_CACHE_DIR') or HOME / '.cache/serpantinum')
SETTINGS = Path(os.environ.get('QS_SETTINGS') or HOME / '.config/serpantinum/settings.json')
MAIN = Path(os.environ.get('MAIN_QML') or Path(__file__).resolve().parent.parent / 'quickshell/Shell.qml')
PRESETS = STATE / 'desktop-presets'


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.desktop-preset-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            stream.write(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
        if path.exists():
            os.chmod(tmp, path.stat().st_mode & 0o777)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def validate(data):
    if not isinstance(data, dict) or data.get('version') != 1:
        raise ValueError('Unsupported desktop preset format')
    settings, widgets, wallpapers = (data.get(k) for k in ('settings', 'widgets', 'wallpapers'))
    if not isinstance(settings, dict) or set(settings) != set(SECTIONS) or any(not isinstance(settings[k], dict) for k in SECTIONS):
        raise ValueError('Preset must contain theme, bar and dock settings')
    if not isinstance(widgets, dict) or not isinstance(wallpapers, dict):
        raise ValueError('Invalid monitor data')
    for monitor, layout in widgets.items():
        if not MONITOR.fullmatch(monitor) or not isinstance(layout, list) or any(not isinstance(x, dict) for x in layout):
            raise ValueError('Invalid widget layout or monitor name')
    for monitor, path in wallpapers.items():
        if not MONITOR.fullmatch(monitor) or not isinstance(path, str) or not Path(path).is_absolute():
            raise ValueError('Invalid wallpaper or monitor name')


def capture():
    settings = read_json(SETTINGS)
    data = {'version': 1, 'settings': {k: settings[k] for k in SECTIONS}, 'widgets': {}, 'wallpapers': {}}
    for path in sorted((STATE / 'widgets').glob('*/layout.json')):
        if MONITOR.fullmatch(path.parent.name):
            data['widgets'][path.parent.name] = read_json(path)
    for path in sorted((CACHE / 'wallpaper').glob('current_*')):
        monitor = path.name[len('current_'):]
        if MONITOR.fullmatch(monitor) and not monitor.endswith('_name') and not monitor.startswith('wallpaper') and path.is_file():
            value = path.read_text(encoding='utf-8').strip()
            if value.startswith('/'):
                data['wallpapers'][monitor] = value
    validate(data)
    return data


def ipc(*args):
    subprocess.run(['quickshell', '-p', str(MAIN), 'ipc', 'call', *args], check=True, capture_output=True, text=True, timeout=15)


def apply(data, offline=False):
    validate(data)
    settings = read_json(SETTINGS)
    if not isinstance(settings, dict):
        raise ValueError('Current settings must be an object')
    for path in data['wallpapers'].values():
        if not Path(path).is_file():
            raise ValueError('Wallpaper is missing: ' + path)
    targets = [SETTINGS] + [STATE / 'widgets' / m / 'layout.json' for m in data['widgets']]
    if any(p.is_symlink() or (p.exists() and not p.is_file()) for p in targets):
        raise ValueError('Refusing to overwrite a symlink or non-file')
    if not offline:
        # Verify the running shell before writing anything.
        ipc('wallpaper', 'getWallpaperPath', next(iter(data['wallpapers']), ''))
    backup = STATE / 'desktop-preset-backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True)
    atomic_write(backup / 'previous-desktop.json', capture())
    for i, target in enumerate(targets):
        if target.exists():
            shutil.copy2(target, backup / f'{i}.bak')
    atomic_write(backup / 'manifest.json', {'targets': [str(p) for p in targets], 'existed': [(backup / f'{i}.bak').exists() for i in range(len(targets))]})
    try:
        settings.update(data['settings'])
        atomic_write(SETTINGS, settings)
        for monitor, layout in data['widgets'].items():
            atomic_write(STATE / 'widgets' / monitor / 'layout.json', layout)
        if not offline:
            for monitor in data['widgets']:
                ipc('widgets-' + monitor, 'reload')
            for monitor, path in data['wallpapers'].items():
                ipc('wallpaper', 'setWallpaper', monitor, path, 'fade')
    except Exception:
        for i, target in enumerate(targets):
            saved = backup / f'{i}.bak'
            if saved.exists():
                shutil.copy2(saved, target)
            elif target.exists():
                target.unlink()
        if not offline:
            previous = read_json(backup / 'previous-desktop.json')
            for monitor in data['widgets']:
                try: ipc('widgets-' + monitor, 'reload')
                except Exception: pass
            for monitor, path in previous['wallpapers'].items():
                try: ipc('wallpaper', 'setWallpaper', monitor, path, 'fade')
                except Exception: pass
        raise
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    for action in ('save', 'apply'):
        p = sub.add_parser(action)
        p.add_argument('name')
        if action == 'apply': p.add_argument('--offline', action='store_true', help='write files without contacting a running shell')
    sub.add_parser('list')
    args = parser.parse_args()
    if args.action == 'list':
        for path in sorted(PRESETS.glob('*.json')): print(path.stem)
        return
    if not NAME.fullmatch(args.name) or args.name.strip() != args.name:
        raise ValueError('Names may contain letters, digits, spaces, underscores and hyphens (up to 64 characters)')
    path = PRESETS / (args.name + '.json')
    if args.action == 'save':
        if path.exists() or path.is_symlink(): raise ValueError('Preset already exists; choose another name')
        atomic_write(path, capture())
        print('Saved:', path)
    else:
        backup = apply(read_json(path), args.offline)
        print('Applied:', args.name, '\nBackup:', backup)


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print('Desktop preset error:', exc, file=sys.stderr)
        sys.exit(1)
