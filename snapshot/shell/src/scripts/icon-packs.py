#!/usr/bin/env python3
"""Synchronize a selected EvhOs application icon pack with native app launchers."""
import argparse
import configparser
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

HOME = Path.home()
DATA = Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share')
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME') or HOME / '.config')
STATE = Path(os.environ.get('QS_STATE_DIR') or HOME / '.local/state/serpantinum')
SOURCE = Path(__file__).resolve().parent.parent
THEMES = ('EvhOs-Satin', 'EvhOs-Facet', 'EvhOs-Mono-Soft', 'EvhOs-Mono-Soft-Light',
          'EvhOs-Pixel-Arcade', 'EvhOs-Type-Density', 'EvhOs-Type-Density-Light', 'EvhOs-Sticker-Pals')


def patch_ini(text, section, key, value):
    lines = text.splitlines(keepends=True)
    out, current, inserted, found_section = [], None, False, False
    for line in lines:
        match = re.match(r'^\s*\[([^\]]+)\]\s*$', line.strip())
        if match:
            if current == section and not inserted:
                if out and not out[-1].endswith('\n'):
                    out[-1] += '\n'
                out.append(key + '=' + value + '\n')
                inserted = True
            current = match.group(1)
            found_section |= current == section
        if current == section and re.match(r'^\s*' + re.escape(key) + r'\s*=', line):
            if not inserted:
                out.append(key + '=' + value + '\n')
                inserted = True
            continue
        out.append(line)
    if current == section and not inserted:
        if out and not out[-1].endswith('\n'):
            out[-1] += '\n'
        out.append(key + '=' + value + '\n')
    elif not found_section:
        if out and not out[-1].endswith('\n'):
            out[-1] += '\n'
        out.extend(['\n[' + section + ']\n', key + '=' + value + '\n'])
    return ''.join(out)


def atomic_write(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError('Refusing to replace a symlink or non-file: ' + str(path))
    fd, temp = tempfile.mkstemp(prefix='.icon-pack-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.chmod(temp, mode)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp): os.unlink(temp)


def status(theme, **values):
    payload = {'theme': theme, **values}
    atomic_write(STATE / 'icon-pack-status.json', (json.dumps(payload, indent=2) + '\n').encode())


def normalize(value):
    value = str(value or '').split('?')[0].split('#')[0].rsplit('/', 1)[-1].lower()
    value = re.sub(r'\.(desktop|png|svg|svgz|xpm|ico)$', '', value)
    value = re.sub(r'^evhos-(satin|facet|mono-soft|pixel-arcade|type-density|sticker-pals|icon)-', '', value)
    return re.sub('[^a-z0-9]', '', value)


def plans(theme, catalog):
    directory = DATA / 'icons' / theme
    if theme not in THEMES or not (directory / 'manifest.json').is_file():
        raise ValueError('The selected icon pack is not installed.')
    manifest = json.loads((directory / 'manifest.json').read_text())
    if not set(catalog['designs']).issubset(manifest['designs']):
        raise ValueError('The selected icon pack is incomplete.')
    lookup = {normalize(name): name for name in catalog['designs']}
    for mapping in [catalog['aliases'], catalog['desktop_icons']]:
        lookup.update({normalize(key): value for key, value in mapping.items()})
    changes = {}
    def add(path, updated):
        if path.is_symlink(): return
        original = path.read_bytes() if path.exists() else None
        data = updated.encode()
        if original != data:
            mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o644
            changes[path] = (original, data, mode)
    roots = [DATA / 'applications']
    roots += [Path(p) / 'applications' for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p]
    seen = set()
    for root in roots:
        for path in sorted(root.rglob('*.desktop')):
            identifier = path.relative_to(root).as_posix().replace('/', '-')
            if identifier in seen: continue
            seen.add(identifier)
            try:
                text = path.read_text()
                entry = configparser.ConfigParser(interpolation=None, strict=False)
                entry.read_string(text)
                icon = entry.get('Desktop Entry', 'Icon', fallback='')
            except (OSError, UnicodeError, configparser.Error): continue
            design = lookup.get(normalize(identifier)) or lookup.get(normalize(icon))
            if not design: continue
            source_icon = directory / '256x256/apps' / (design + '.png')
            if not source_icon.is_file(): raise ValueError('Missing icon: ' + design)
            add(DATA / 'applications' / identifier, patch_ini(text, 'Desktop Entry', 'Icon', str(source_icon)))
    for version in ['gtk-3.0', 'gtk-4.0']:
        path = CONFIG / version / 'settings.ini'
        add(path, patch_ini(path.read_text() if path.exists() else '', 'Settings', 'gtk-icon-theme-name', theme))
    for version in ['qt5ct', 'qt6ct']:
        path = CONFIG / version / (version + '.conf')
        add(path, patch_ini(path.read_text() if path.exists() else '', 'Appearance', 'icon_theme', theme))
    return changes


def sync(theme, system_commands=True):
    catalog = json.loads((SOURCE / 'assets/icon-packs/catalog.json').read_text())
    changes = plans(theme, catalog)
    previous_gsettings = None
    gsettings = shutil.which('gsettings') if system_commands else None
    if gsettings:
        result = subprocess.run([gsettings, 'get', 'org.gnome.desktop.interface', 'icon-theme'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0: previous_gsettings = result.stdout.strip()
    status(theme, running=True, error='')
    written = []
    gsettings_changed = False
    try:
        for path, (original, updated, mode) in changes.items():
            if (path.read_bytes() if path.exists() else None) != original:
                raise ValueError('An application setting changed while selecting the icon pack. Try again.')
            atomic_write(path, updated, mode)
            written.append(path)
        if gsettings and previous_gsettings is not None:
            subprocess.run([gsettings, 'set', 'org.gnome.desktop.interface', 'icon-theme', theme], check=True, capture_output=True, text=True, timeout=10)
            gsettings_changed = True
        status(theme, running=False, error='', changed=len(written))
    except BaseException as error:
        recovery_errors = []
        for path in reversed(written):
            original, updated, mode = changes[path]
            try:
                if original is None: path.unlink(missing_ok=True)
                else: atomic_write(path, original, mode)
            except OSError as recovery: recovery_errors.append(str(recovery))
        if gsettings_changed:
            try: subprocess.run([gsettings, 'set', 'org.gnome.desktop.interface', 'icon-theme', previous_gsettings], check=True, capture_output=True, timeout=10)
            except (OSError, subprocess.SubprocessError) as recovery: recovery_errors.append(str(recovery))
        message = str(error) + ('; recovery: ' + '; '.join(recovery_errors) if recovery_errors else '')
        status(theme, running=False, error=message)
        raise
    # Launcher/database refresh is best-effort; running app windows can retain
    # their own embedded icon until that application refreshes it.
    if system_commands and shutil.which('update-desktop-database'):
        subprocess.run(['update-desktop-database', str(DATA / 'applications')], capture_output=True, timeout=15)
    return {'ok': True, 'theme': theme, 'changed': len(written), 'message': 'Application icons updated.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['sync'])
    parser.add_argument('theme', choices=THEMES)
    parser.add_argument('--no-system-commands', action='store_true')
    args = parser.parse_args()
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'icon-packs.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try: result = sync(args.theme, system_commands=not args.no_system_commands)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            status(args.theme, running=False, error=str(error))
            print(json.dumps({'ok':False, 'error':str(error)})); return 1
    print(json.dumps(result)); return 0


if __name__ == '__main__':
    sys.exit(main())


