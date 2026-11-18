#!/usr/bin/env python3
"""Capture the allowlisted desktop into this repository; preview unless --apply is set."""
import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT/'tools/capture-spec.json').read_text())
BLOCKED = re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)')


def excluded(path):
    return any(part in ('.git', '__pycache__', 'node_modules', 'icon-theme.cache') or 'backup-' in part or '.before' in part or part.endswith(('.bak', '.pyc', '.log', '.so', '~')) for part in path.parts)


def entries(directory):
    return [p for p in directory.rglob('*') if not excluded(p.relative_to(directory)) and (p.is_file() or p.is_symlink())] if directory.is_dir() else []


def scan_text(data, path):
    if b'\0' in data:
        return
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return
    if BLOCKED.search(text):
        raise ValueError('Credential-like content in '+str(path))
    if path.suffix == '.json' and '/assets/' not in path.as_posix():
        try:
            value = json.loads(text)
        except json.JSONDecodeError:
            return
        def inspect(value):
            if isinstance(value, dict):
                for key, item in value.items():
                    if isinstance(item, str) and item.strip() and re.search(r'(api.?key|token|password|secret|credential)', key, re.I):
                        raise ValueError('Nonempty credential field in '+str(path))
                    inspect(item)
            elif isinstance(value, list):
                for item in value:
                    inspect(item)
        inspect(value)


def manifest(repository=ROOT):
    result = {}
    for path in sorted((repository/'snapshot').rglob('*')):
        if path == repository/'snapshot/manifest.json' or excluded(path.relative_to(repository)):
            continue
        if path.is_symlink():
            result[str(path.relative_to(repository))] = {'mode': '120000', 'target': os.readlink(path)}
        elif path.is_file():
            result[str(path.relative_to(repository))] = {'mode': '100755' if path.stat().st_mode & 0o111 else '100644', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    return result


def pack_icons(directory):
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w|') as archive:
            aliases = {}
            for path in sorted(entries(directory)):
                if path.is_symlink():
                    raise ValueError('Unexpected symlink in icon pack: '+str(path))
                name = path.relative_to(directory.parent).as_posix()
                data = path.read_bytes()
                scan_text(data, Path('snapshot/assets/icon-packs')/name)
                info = tarfile.TarInfo(name)
                digest = hashlib.sha256(data).digest()
                if digest in aliases:
                    info.type = tarfile.LNKTYPE
                    info.linkname = aliases[digest]
                    archive.addfile(info)
                else:
                    info.size = len(data)
                    archive.addfile(info, io.BytesIO(data))
                    aliases[digest] = name
    return buffer.getvalue()


def capture(home, apply=False, system_root=Path("/")):
    shell = home/'.local/share/serpantinum'
    if not (shell/'src/quickshell/Shell.qml').is_file():
        raise ValueError('The live Serpantinum source is missing.')
    mapping = {}
    # Keep the existing asset/license allowlist; discover new shell source files.
    for path in entries(ROOT/'snapshot/shell'):
        relative = path.relative_to(ROOT/'snapshot/shell')
        source = shell/relative
        if source.is_file() or source.is_symlink():
            mapping[path] = source
    for directory in SPEC['shell_directories']:
        for source in entries(shell/directory):
            mapping[ROOT/'snapshot/shell'/source.relative_to(shell)] = source
    for source in entries(shell/'src/assets'):
        relative = str(source.relative_to(shell))
        if relative not in SPEC['excluded_new_assets']:
            mapping[ROOT/'snapshot/shell'/relative] = source
    for relative in SPEC['home_files']:
        source = home/relative
        if source.is_file() or source.is_symlink():
            mapping[ROOT/'snapshot/home'/relative] = source
    for directory in SPEC['home_directories']:
        for source in entries(home/directory):
            mapping[ROOT/'snapshot/home'/source.relative_to(home)] = source

    packs = {}
    for name in SPEC.get('icon_packs', []):
        directory = home/'.local/share/icons'/name
        if (directory/'index.theme').is_file():
            packs[ROOT/'snapshot/icon-packs'/f'{name}.tar.gz'] = directory

    # Optional system appearance assets are versioned, never installed by home restore.
    captured_system = []
    for relative, destination in SPEC.get('system_directories', {}).items():
        directory = system_root / relative.lstrip('/')
        if directory.is_dir():
            captured_system.append(relative)
            for source in entries(directory):
                mapping[ROOT/'snapshot/system'/destination/source.relative_to(directory)] = source

    # Capture media used by the saved desktop/presets, rather than the whole library.
    media = set()
    wallpaper_root = home/'Pictures/Wallpapers'
    preset_assets = home/'.local/state/serpantinum/desktop-preset-assets'
    active_media = []
    for state in sorted((home/'.cache/serpantinum/wallpaper').glob('current_*')):
        if state.is_file() and state.stat().st_size < 4096 and state.suffix not in ('.json', '.png'):
            candidate = Path(state.read_text().strip())
            if candidate.is_file() and candidate.is_relative_to(wallpaper_root):
                active_media.append(candidate)
    fallbacks = {}
    def media_reference(value):
        if isinstance(value, str) and value.startswith(str(preset_assets)+'/'):
            asset = Path(value)
            if not asset.is_file() or not asset.resolve().is_relative_to(preset_assets.resolve()):
                raise ValueError('Missing or invalid preset wallpaper asset: '+value)
            media.add(asset)
            return value
        if isinstance(value, str) and value.startswith(str(wallpaper_root)+'/'):
            old = Path(value)
            if old.is_dir():
                return value
            candidate = old if old.is_file() else wallpaper_root/('Videos' if old.suffix.lower() in ('.mp4', '.mkv', '.mov', '.webm') else 'Pictures')/old.name
            if not candidate.is_file() and active_media:
                candidate = active_media[0]
                fallbacks[value] = str(candidate)
            if candidate.is_file():
                media.add(candidate)
                return str(candidate)
        if isinstance(value, dict):
            return {key: media_reference(item) for key, item in value.items()}
        if isinstance(value, list):
            return [media_reference(item) for item in value]
        return value

    replacements = {}
    for target, source in list(mapping.items()):
        if source == home/'.config/hypr/hyprland/gestures.lua':
            replacements[target] = source.read_bytes().replace(b'/usr/bin/qs -p ', b'quickshell -p ')
        elif source.suffix == '.json' and (source.parent == preset_assets.parent/'desktop-presets' or source.name == 'wallpaper-ring-favorites.json'):
            value = media_reference(json.loads(source.read_text()))
            replacements[target] = (json.dumps(value, indent=2)+'\n').encode()
        elif source.parent == home/'.cache/serpantinum/wallpaper' and source.name.startswith('current_') and source.stat().st_size < 4096 and source.suffix not in ('.json', '.png'):
            value = media_reference(source.read_text().strip())
            if value != source.read_text().strip():
                replacements[target] = value.encode()
    index = preset_assets/'sources.json'
    if index.is_file():
        selected = {source: details for source, details in json.loads(index.read_text()).items()
                    if Path(details['asset']) in media}
        if selected:
            target = ROOT/'snapshot/home'/index.relative_to(home)
            mapping[target] = index
            replacements[target] = (json.dumps(selected, indent=2)+'\n').encode()
    for source in media:
        mapping[ROOT/'snapshot/home'/source.relative_to(home)] = source
        if source.is_relative_to(preset_assets) and source.suffix.lower() in ('.mp4', '.mkv', '.mov', '.webm'):
            preview = preset_assets.parent/'desktop-preset-asset-previews'/f'{source.parent.name}.png'
            if preview.is_file():
                mapping[ROOT/'snapshot/home'/preview.relative_to(home)] = preview

    control = preset_assets.parent/'desktop-preset-session.json'
    if control.is_file():
        active = json.loads(control.read_text()).get('activeName', '')
        if active and any(source.stem == active and source.parent == preset_assets.parent/'desktop-presets'
                          for source in mapping.values()):
            target = ROOT/'snapshot/home'/control.relative_to(home)
            mapping[target] = control
            replacements[target] = (json.dumps({'version': 1, 'activeName': active, 'session': None, 'undo': None}, indent=2)+'\n').encode()

    payloads = {}
    for target, source in mapping.items():
        if source.is_symlink():
            payloads[target] = ('link', os.readlink(source), 0)
        else:
            before = source.stat()
            data = replacements.get(target, source.read_bytes())
            after = source.stat()
            if (before.st_mtime_ns, before.st_size) != (after.st_mtime_ns, after.st_size):
                raise ValueError('Source changed during capture: '+str(source))
            scan_text(data, target.relative_to(ROOT))
            payloads[target] = ('file', data, source.stat().st_mode & 0o777)
    print(('CAPTURE' if apply else 'PREVIEW')+f': {len(payloads)} files; {len(media)} referenced wallpaper assets; {len(packs)} icon packs')
    if not apply:
        return
    for target, directory in packs.items():
        payloads[target] = ('file', pack_icons(directory), 0o644)
    # Remove deleted files only from explicitly managed source/home locations.
    for relative in SPEC['home_files']:
        target = ROOT/'snapshot/home'/relative
        if target not in payloads and (target.is_file() or target.is_symlink()):
            target.unlink()
    for directory in SPEC['home_directories']:
        for target in entries(ROOT/'snapshot/home'/directory):
            if target not in payloads:
                target.unlink()
    for directory in SPEC['shell_directories']:
        for target in entries(ROOT/'snapshot/shell'/directory):
            if target not in payloads:
                target.unlink()
    saved_state = ROOT/'snapshot/home'/preset_assets.parent.relative_to(home)
    for target in [saved_state/control.name, *entries(saved_state/preset_assets.name),
                   *entries(saved_state/'desktop-preset-asset-previews')]:
        if target not in payloads and (target.is_file() or target.is_symlink()):
            target.unlink()
    for target, (kind, data, mode) in payloads.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink():
            target.unlink()
        if kind == 'link':
            if target.exists():
                target.unlink()
            target.symlink_to(data)
        else:
            target.write_bytes(data)
            target.chmod(mode)
    metadata = {'captured_at': datetime.now(timezone.utc).isoformat(), 'source_home': str(home), 'wallpaper_assets': sorted(str(path.relative_to(home)) for path in media), 'missing_wallpaper_fallbacks': fallbacks, 'packages': {}, 'system_asset_sources': captured_system}
    if shutil.which('pacman'):
        for package in ('hyprland', 'noctalia-qs', 'qt6-base', 'qt6-declarative', 'qt6-multimedia', 'python', 'python-pillow', 'ffmpeg'):
            result = subprocess.run(['pacman', '-Q', package], capture_output=True, text=True)
            if result.returncode == 0:
                metadata['packages'][package] = result.stdout.strip().split(' ', 1)[1]
    (ROOT/'snapshot/metadata.json').write_text(json.dumps(metadata, indent=2)+'\n')
    (ROOT/'snapshot/manifest.json').write_text(json.dumps(manifest(), indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--system-root', type=Path, default=Path('/'), help='root for optional system appearance assets')
    args = parser.parse_args()
    capture(args.home.expanduser().resolve(), args.apply, args.system_root.resolve())
