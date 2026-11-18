#!/usr/bin/env python3
"""Transactional desktop presets and recoverable customization sessions."""
import argparse
import copy
import shutil
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import uuid
from contextlib import contextmanager

NAME = re.compile(r'^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$')
MONITOR = re.compile(r'^[A-Za-z0-9_-]+$')
SECTIONS = ('theme', 'bar', 'dock')
HOME = Path.home()
STATE = Path(os.environ.get('QS_STATE_DIR') or HOME / '.local/state/serpantinum')
CACHE = Path(os.environ.get('QS_CACHE_DIR') or HOME / '.cache/serpantinum')
SETTINGS = Path(os.environ.get('QS_SETTINGS') or HOME / '.config/serpantinum/settings.json')
MAIN = Path(os.environ.get('MAIN_QML') or Path(__file__).resolve().parent.parent / 'quickshell/Shell.qml')
PRESETS = STATE / 'desktop-presets'
CONTROL = STATE / 'desktop-preset-session.json'
OFFLINE = False
SELECTED_SECTIONS = None
KEEP_APPS = False
EXPECTED = ''
REVIEW_SOURCE = 'preset'
ALL_COMPONENTS = ('theme', 'bar', 'dock', 'widgets', 'wallpaper')
COMPONENT_LABELS = {'theme': 'Appearance', 'bar': 'Topbar', 'dock': 'Dock', 'widgets': 'Widgets', 'wallpaper': 'Wallpaper'}
HISTORY = STATE / 'desktop-preset-backups'
VISUAL_KEYS = {
    'launcher': ('position', 'width', 'itemCount'),
    'osd': ('horizontalPosition', 'verticalPosition', 'orientation', 'showCapsLock', 'showNumLock', 'showAirplane', 'attachToBar'),
    'notifications': ('position', 'horizontalPosition', 'verticalPosition', 'showEmptyGraphic'),
    'lockscreen': ('backgroundMode', 'customBackground'),
}




def read_json(path, default=None):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except FileNotFoundError:
        if default is not None:
            return copy.deepcopy(default)
        raise


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError('Refusing to replace a symlink or non-file: ' + str(path))
    fd, temp = tempfile.mkstemp(prefix='.desktop-preset-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False, allow_nan=False)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        if path.exists():
            os.chmod(temp, path.stat().st_mode & 0o777)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


@contextmanager
def operation_lock():
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'desktop-presets.lock').open('a') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError('Another preset operation is still running. Try again shortly.') from exc
        yield


def preset_path(name):
    if not isinstance(name, str) or not NAME.fullmatch(name) or name.strip() != name:
        raise ValueError('Use 1–64 letters, digits, spaces, underscores or hyphens; start with a letter or digit.')
    path = PRESETS / (name + '.json')
    if path.is_symlink():
        raise ValueError('Preset may not be a symlink.')
    return path


def ensure_unused(name, except_name=''):
    path = preset_path(name)
    for other in PRESETS.glob('*.json'):
        if other.stem != except_name and other.stem.casefold() == name.casefold():
            raise ValueError('A preset with that name already exists.')
    return path


def validate(data):
    if not isinstance(data, dict) or data.get('version') not in (1, 2, 3):
        raise ValueError('Unsupported desktop preset format.')
    settings, widgets, wallpapers = (data.get(k) for k in ('settings', 'widgets', 'wallpapers'))
    if not isinstance(settings, dict) or set(settings) != set(SECTIONS) or any(not isinstance(settings[k], dict) for k in SECTIONS):
        raise ValueError('Preset must contain theme, bar and dock settings.')
    if not isinstance(widgets, dict) or not isinstance(wallpapers, dict):
        raise ValueError('Invalid monitor data.')
    for monitor, layout in widgets.items():
        if not isinstance(monitor, str) or not MONITOR.fullmatch(monitor) or not isinstance(layout, list):
            raise ValueError('Invalid widget layout or monitor name.')
        ids = set()
        for item in layout:
            if not isinstance(item, dict):
                raise ValueError('Invalid widget record.')
            widget_id = item.get('wId', item.get('id'))
            if widget_id is not None:
                if str(widget_id) in ids:
                    raise ValueError('Duplicate widget identifier.')
                ids.add(str(widget_id))
    for monitor, path in wallpapers.items():
        if not isinstance(monitor, str) or not MONITOR.fullmatch(monitor) or not isinstance(path, str) or (path and not Path(path).is_absolute()):
            raise ValueError('Invalid wallpaper or monitor name.')
    visual = data.get('visual', {})
    if not isinstance(visual, dict) or set(visual) - set(VISUAL_KEYS):
        raise ValueError('Invalid visual settings.')
    for section, values in visual.items():
        if not isinstance(values, dict) or set(values) - set(VISUAL_KEYS[section]):
            raise ValueError('Invalid visual setting keys.')
    # Reject non-finite numbers even in nested widget properties.
    json.dumps(data, allow_nan=False)


def canonical(data):
    result = copy.deepcopy({key: data[key] for key in ('settings', 'widgets', 'wallpapers')})
    theme = result['settings']['theme']
    theme.setdefault('iconPack', 'EvhOs-Satin')
    if theme.get('matugen') or theme.get('activePreset') == 'Matugen':
        theme.pop('colors', None)  # Generated colors are not a user edit.
    result['settings']['dock'].pop('editing', None)
    index = read_json(STATE / 'desktop-preset-assets/sources.json', {})
    result['wallpapers'] = {monitor: asset_identity(path, index) for monitor, path in result['wallpapers'].items()}
    result['visual'] = copy.deepcopy(data.get('visual', {}))
    lock = result['visual'].get('lockscreen', {})
    if lock.get('customBackground'):
        lock['customBackground'] = asset_identity(lock['customBackground'], index)
    return result


def fingerprint(data):
    validate(data)
    return hashlib.sha256(json.dumps(canonical(data), sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def ipc(*args):
    result = subprocess.run(['quickshell', '-p', str(MAIN), 'ipc', 'call', *args], check=True,
                            capture_output=True, text=True, timeout=15)
    return result.stdout.strip()


def ipc_json(*args, expected_type=None):
    response = ipc(*args)
    endpoint = ' '.join(args[:2])
    if not response:
        raise ValueError('The shell returned no data for ' + endpoint + '. Reload the shell and try again.')
    try:
        value = json.loads(response)
    except json.JSONDecodeError as exc:
        raise ValueError('The shell returned invalid JSON for ' + endpoint + '. Reload the shell and try again.') from exc
    if expected_type is not None and not isinstance(value, expected_type):
        raise ValueError('The shell returned an invalid snapshot for ' + endpoint + '.')
    return value


def widget_payload(layout):
    # CLI11 expands an argument surrounded by [] as a vector. A JSON object
    # preserves both empty arrays and complete widget records through the CLI.
    return json.dumps({'widgets': layout}, ensure_ascii=False, allow_nan=False)


def require_widget_protocol(monitors, data):
    for monitor in monitors:
        if ipc('widgets-' + monitor, 'protocolVersion') != '4':
            raise ValueError('The widget adapter on ' + monitor + ' needs a shell reload. No desktop settings were changed.')
        layout = data['widgets'].get(monitor, [])
        echoed = ipc_json('widgets-' + monitor, 'inspectLayout', widget_payload(layout), expected_type=list)
        if echoed != layout:
            raise ValueError('Widget data changed in transit on ' + monitor + '. No desktop settings were changed.')


def expect_ok(*args):
    result = ipc(*args)
    if result != 'ok':
        raise ValueError('Shell rejected ' + args[1] + ': ' + result)


def wait_until(check, message, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if check():
                return
        except (OSError, ValueError):
            pass
        time.sleep(0.05)
    raise ValueError(message)


def connected_monitors():
    monitors = ipc_json('desktopPresetConfig', 'monitors', expected_type=list)
    if not isinstance(monitors, list) or any(not isinstance(m, str) or not MONITOR.fullmatch(m) for m in monitors):
        raise ValueError('Shell returned invalid monitor names.')
    return monitors


def capture(live=False, flush=True):
    if live and flush:
        expect_ok('redactor', 'flush')
    settings = ipc_json('desktopPresetConfig', 'get', expected_type=dict) if live else read_json(SETTINGS)
    data = {'version': 3, 'settings': {k: copy.deepcopy(settings[k]) for k in SECTIONS}, 'widgets': {}, 'wallpapers': {}, 'visual': capture_visual(settings)}
    data['settings']['dock']['editing'] = False
    for path in sorted((STATE / 'widgets').glob('*/layout.json')):
        if MONITOR.fullmatch(path.parent.name):
            data['widgets'][path.parent.name] = read_json(path)
    for path in sorted((CACHE / 'wallpaper').glob('current_*')):
        monitor = path.name[len('current_'):]
        if MONITOR.fullmatch(monitor) and not monitor.endswith('_name') and not monitor.startswith('wallpaper') and path.is_file():
            value = path.read_text(encoding='utf-8').strip()
            if not value or value.startswith('/'):
                data['wallpapers'][monitor] = value
    if live:
        # In-memory models are authoritative, including a drag inside the 300ms debounce.
        for monitor in connected_monitors():
            data['widgets'][monitor] = ipc_json('widgets-' + monitor, 'list', expected_type=list)
            data['wallpapers'][monitor] = ipc('wallpaper', 'getWallpaperPath', monitor)
    validate(data)
    return data


def capture_for_save():
    if OFFLINE:
        return capture()
    # End the gesture and flush editor proxies before reading the live models.
    ipc('redactor', 'close')
    data = capture(live=True)
    wait_until(lambda: ipc('desktopPresetConfig', 'ready') == 'ok', 'Settings have not finished saving.')
    for monitor in connected_monitors():
        expect_ok('widgets-' + monitor, 'save')
        expected = data['widgets'][monitor]
        wait_until(lambda m=monitor, v=expected: ipc('widgets-' + m, 'ready') == 'ok'
                   and read_json(STATE / 'widgets' / m / 'layout.json') == v,
                   'Widget changes have not finished saving on ' + monitor)
    return data


def load_control():
    result = read_json(CONTROL, {'version': 1, 'activeName': '', 'session': None, 'undo': None})
    if not isinstance(result, dict) or result.get('version') != 1:
        raise ValueError('Invalid desktop editing session. Restore the session file from backup.')
    return result


def write_live(data, monitors):
    expect_ok('desktopPresetConfig', 'apply', json.dumps(settings_payload(data)))
    expected = {}
    for monitor, layout in data['widgets'].items():
        if monitor in monitors:
            # Mutating IPC returns only an acknowledgement. Read the snapshot separately.
            expect_ok('widgets-' + monitor, 'stageLayout', widget_payload(layout))
            expected[monitor] = ipc_json('widgets-' + monitor, 'list', expected_type=list)
        else:
            atomic_write(STATE / 'widgets' / monitor / 'layout.json', layout)
    for monitor in monitors:
        expect_ok('widgets-' + monitor, 'commitTransaction')
    wait_until(lambda: ipc('desktopPresetConfig', 'ready') == 'ok' and all(read_json(SETTINGS).get(k) == data['settings'][k] for k in SECTIONS) and visual_matches(read_json(SETTINGS), data),
               'Settings did not finish saving.')
    for monitor, layout in expected.items():
        wait_until(lambda m=monitor, v=layout: ipc('widgets-' + m, 'ready') == 'ok' and read_json(STATE / 'widgets' / m / 'layout.json') == v,
                   'Widgets did not finish saving on ' + monitor)
    for monitor, path in data['wallpapers'].items():
        if monitor not in monitors:
            continue
        if path:
            ipc('wallpaper', 'setWallpaper', monitor, path, 'fade')
        else:
            ipc('wallpaper', 'clearWallpaper', monitor)
        wait_until(lambda m=monitor, p=path: ipc('wallpaper', 'getWallpaperPath', m) == p,
                   'Wallpaper did not finish changing on ' + monitor)


def apply(data, reason="Before changing desktop"):
    """Stage complete desktop changes; restore every covered component on failure."""
    validate(data)
    for path in data['wallpapers'].values():
        if path and not Path(path).is_file():
            raise ValueError('Wallpaper is missing: ' + path)
    targets = [SETTINGS] + [STATE / 'widgets' / m / 'layout.json' for m in data['widgets']]
    if any(p.is_symlink() or (p.exists() and not p.is_file()) for p in targets):
        raise ValueError('Refusing to replace a symlink or non-file.')
    live_monitors = [] if OFFLINE else connected_monitors()
    if not OFFLINE:
        require_widget_protocol(live_monitors, data)
    previous = freeze_wallpapers(capture(live=not OFFLINE), strict=False)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    backup = STATE / 'desktop-preset-backups' / stamp
    atomic_write(backup / 'previous-desktop.json', previous)
    atomic_write(backup / 'control.json', load_control())
    atomic_write(backup / 'metadata.json', {'id': stamp, 'createdAt': now(), 'reason': reason, 'name': load_control().get('activeName', ''), 'kind': 'desktop'})
    monitors = []
    started = []
    try:
        if OFFLINE:
            settings = read_json(SETTINGS)
            settings.update(data['settings'])
            settings = apply_visual(settings, data.get('visual', {}))
            atomic_write(SETTINGS, settings)
            for monitor, layout in data['widgets'].items():
                atomic_write(STATE / 'widgets' / monitor / 'layout.json', layout)
            for monitor, path in data['wallpapers'].items():
                target = CACHE / 'wallpaper' / ('current_' + monitor)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(path, encoding='utf-8')
        else:
            monitors = live_monitors
            expect_ok('desktopPresetConfig', 'beginTransaction')
            for monitor in monitors:
                expect_ok('widgets-' + monitor, 'beginTransaction')
                started.append(monitor)
            wait_until(lambda: all(ipc('widgets-' + m, 'ready') == 'ok' for m in monitors), 'A widget save is still in progress.')
            write_live(data, monitors)
    except Exception as original:
        try:
            if OFFLINE:
                settings = read_json(SETTINGS)
                settings.update(previous['settings'])
                settings = apply_visual(settings, previous.get('visual', {}))
                atomic_write(SETTINGS, settings)
                for monitor, layout in previous['widgets'].items():
                    atomic_write(STATE / 'widgets' / monitor / 'layout.json', layout)
                for monitor in set(data['widgets']) - set(previous['widgets']):
                    (STATE / 'widgets' / monitor / 'layout.json').unlink(missing_ok=True)
                for monitor in set(data['wallpapers']) | set(previous['wallpapers']):
                    target = CACHE / 'wallpaper' / ('current_' + monitor)
                    if monitor in previous['wallpapers']:
                        target.write_text(previous['wallpapers'][monitor], encoding='utf-8')
                    else:
                        target.unlink(missing_ok=True)
            else:
                rollback_errors = []
                try:
                    expect_ok('desktopPresetConfig', 'apply', json.dumps(settings_payload(previous)))
                    wait_until(lambda: ipc('desktopPresetConfig', 'ready') == 'ok' and
                               all(read_json(SETTINGS).get(k) == previous['settings'][k] for k in SECTIONS) and visual_matches(read_json(SETTINGS), previous),
                               'Previous settings did not finish saving.')
                except Exception as exc:
                    rollback_errors.append('settings: ' + str(exc))
                for monitor in set(previous['widgets']) | set(data['widgets']):
                    try:
                        layout = previous['widgets'].get(monitor, [])
                        if monitor in started:
                            expect_ok('widgets-' + monitor, 'beginTransaction')
                            expect_ok('widgets-' + monitor, 'stageLayout', widget_payload(layout))
                            expected = ipc_json('widgets-' + monitor, 'list', expected_type=list)
                            expect_ok('widgets-' + monitor, 'commitTransaction')
                            wait_until(lambda m=monitor, v=expected: ipc('widgets-' + m, 'ready') == 'ok'
                                       and read_json(STATE / 'widgets' / m / 'layout.json') == v,
                                       'Previous widget layout did not finish saving on ' + monitor)
                        elif monitor in previous['widgets']:
                            atomic_write(STATE / 'widgets' / monitor / 'layout.json', layout)
                        else:
                            (STATE / 'widgets' / monitor / 'layout.json').unlink(missing_ok=True)
                    except Exception as exc:
                        rollback_errors.append('widgets on ' + monitor + ': ' + str(exc))
                # A broken widget adapter must not prevent wallpaper recovery.
                for monitor in set(previous['wallpapers']) | set(data['wallpapers']):
                    if monitor not in live_monitors:
                        continue
                    try:
                        path = previous['wallpapers'].get(monitor, '')
                        if path:
                            ipc('wallpaper', 'setWallpaper', monitor, path, 'fade')
                        else:
                            ipc('wallpaper', 'clearWallpaper', monitor)
                        wait_until(lambda m=monitor, v=path: ipc('wallpaper', 'getWallpaperPath', m) == v,
                                   'Previous wallpaper did not finish changing on ' + monitor)
                    except Exception as exc:
                        rollback_errors.append('wallpaper on ' + monitor + ': ' + str(exc))
                if rollback_errors:
                    raise ValueError('; '.join(rollback_errors))
        except Exception as rollback_error:
            raise ValueError(f'Apply failed ({original}); restore was incomplete ({rollback_error}). Recovery: {backup}') from original
        raise
    finally:
        if not OFFLINE:
            for monitor in started:
                try:
                    expect_ok('widgets-' + monitor, 'endTransaction')
                except (ValueError, subprocess.SubprocessError):
                    pass
            try:
                expect_ok('desktopPresetConfig', 'endTransaction')
            except (ValueError, subprocess.SubprocessError):
                pass
    return previous


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def require_no_session(control):
    if control.get('session'):
        raise ValueError('Finish the current editing session before this action.')


def capture_visual(settings):
    return {section: {key: copy.deepcopy(settings.get(section, {}).get(key)) for key in fields}
            for section, fields in VISUAL_KEYS.items()}


def apply_visual(settings, visual):
    result = copy.deepcopy(settings)
    for section, values in visual.items():
        current = result.setdefault(section, {})
        for key, value in values.items():
            if value is None:
                current.pop(key, None)
            else:
                current[key] = copy.deepcopy(value)
    return result


def visual_matches(settings, data):
    return all(settings.get(section, {}).get(key) == value
               for section, values in data.get('visual', {}).items() for key, value in values.items())


def settings_payload(data):
    result = copy.deepcopy(data['settings'])
    result['__visual'] = copy.deepcopy(data.get('visual', {}))
    return result


def version_fingerprint(data):
    """Stable saved-file version guard, independent of source asset indexing."""
    validate(data)
    value = copy.deepcopy({key: data.get(key, {}) for key in ('settings', 'widgets', 'wallpapers', 'visual')})
    value['version'] = data['version']
    value['settings']['dock'].pop('editing', None)
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def owned_asset_digest(path):
    source = Path(path)
    directory = STATE / 'desktop-preset-assets'
    if source.parent.parent == directory and re.fullmatch(r'[0-9a-f]{64}', source.parent.name):
        return source.parent.name
    if source.parent == directory and re.fullmatch(r'[0-9a-f]{64}\.[A-Za-z0-9]+', source.name):
        return source.stem
    return ''


def asset_identity(path, index):
    if not path:
        return path
    source = Path(path)
    if owned_asset_digest(source):
        return 'sha256:' + owned_asset_digest(source)
    record = index.get(str(source))
    if isinstance(record, dict) and not source.exists() and Path(record.get('asset', '')).is_file():
        return 'sha256:' + owned_asset_digest(record['asset'])
    if isinstance(record, dict) and source.is_file():
        info = source.stat()
        if record.get('size') == info.st_size and record.get('mtime') == info.st_mtime_ns and Path(record.get('asset', '')).is_file():
            return 'sha256:' + owned_asset_digest(record['asset'])
    return str(source)


def asset_preview_path(path):
    return STATE / 'desktop-preset-asset-previews' / ((owned_asset_digest(path) or Path(path).stem) + '.png')


def preserve_asset(path):
    """Own the wallpaper bytes, rather than depending on a mutable source path."""
    source = Path(path)
    directory = STATE / 'desktop-preset-assets'
    if not source.is_file():
        raise ValueError('Wallpaper file is unavailable: ' + str(source))
    if owned_asset_digest(source):
        return str(source)
    directory.mkdir(parents=True, exist_ok=True)
    index_path = directory / 'sources.json'
    index = read_json(index_path, {})
    info = source.stat()
    known = index.get(str(source), {})
    if known.get('size') == info.st_size and known.get('mtime') == info.st_mtime_ns and Path(known.get('asset', '')).is_file():
        return known['asset']
    descriptor, temporary = tempfile.mkstemp(prefix='.wallpaper-', dir=directory)
    try:
        digest = hashlib.sha256()
        with source.open('rb') as incoming, os.fdopen(descriptor, 'wb') as outgoing:
            while True:
                block = incoming.read(1024 * 1024)
                if not block:
                    break
                digest.update(block)
                outgoing.write(block)
            outgoing.flush()
            os.fsync(outgoing.fileno())
        after = source.stat()
        if (info.st_size, info.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            raise ValueError('The wallpaper changed while it was being saved. Try again.')
        extension = source.suffix.lower() if re.fullmatch(r'\.[a-zA-Z0-9]+', source.suffix) else '.asset'
        asset_folder = directory / digest.hexdigest()
        asset_folder.mkdir(exist_ok=True)
        safe_name = re.sub(r'[^A-Za-z0-9._ -]', '_', source.name)[:180] or ('wallpaper' + extension)
        existing_files = sorted(p for p in asset_folder.iterdir() if p.is_file())
        target = existing_files[0] if existing_files else asset_folder / safe_name
        if target.exists():
            os.unlink(temporary)
        else:
            os.chmod(temporary, 0o644)
            os.replace(temporary, target)
        index[str(source)] = {'asset': str(target), 'size': info.st_size, 'mtime': info.st_mtime_ns, 'name': source.name}
        atomic_write(index_path, index)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    if extension in ('.mp4', '.mkv', '.mov', '.webm'):
        preview = asset_preview_path(target)
        if not preview.exists() and shutil.which('ffmpeg'):
            preview.parent.mkdir(parents=True, exist_ok=True)
            temporary_preview = preview.with_name('.' + preview.name)
            try:
                result = subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-ss', '00:00:01',
                                         '-i', str(target), '-frames:v', '1', '-vf', 'scale=640:-2', str(temporary_preview)],
                                        capture_output=True, timeout=10)
                if result.returncode == 0 and temporary_preview.is_file():
                    os.replace(temporary_preview, preview)
            except (OSError, subprocess.SubprocessError):
                pass
            finally:
                temporary_preview.unlink(missing_ok=True)
    return str(target)


def freeze_wallpapers(data, strict=True):
    result = copy.deepcopy(data)
    names = result.setdefault('wallpaperNames', {})
    index = read_json(STATE / 'desktop-preset-assets/sources.json', {})
    for monitor, path in result['wallpapers'].items():
        if not path:
            continue
        if not Path(path).is_file():
            known = index.get(path, {})
            if Path(known.get('asset', '')).is_file():
                result['wallpapers'][monitor] = known['asset']
                names.setdefault(monitor, known.get('name') or Path(path).name)
                continue
            if strict:
                raise ValueError('Choose the wallpaper again before saving this theme: ' + path)
            continue
        if monitor not in names:
            original = next((value.get('name') for value in index.values() if isinstance(value, dict) and value.get('asset') == path), '')
            names[monitor] = original or Path(path).name
        result['wallpapers'][monitor] = preserve_asset(path)
    lock = result.get('visual', {}).get('lockscreen', {})
    background = lock.get('customBackground')
    if isinstance(background, str) and background.startswith('/') and Path(background).is_file():
        lock['customBackground'] = preserve_asset(background)
    return result


def persist_active_wallpaper_paths(data):
    # The wallpaper engine restores these paths on boot. Point them at the
    # preserved media too, without replaying a transition on the current screen.
    for monitor, path in data['wallpapers'].items():
        if path and not Path(path).is_file():
            continue
        folder = CACHE / 'wallpaper'
        folder.mkdir(parents=True, exist_ok=True)
        values = {'current_' + monitor: path,
                  'current_' + monitor + '_name': data.get('wallpaperNames', {}).get(monitor, Path(path).name if path else '')}
        for name, value in values.items():
            target = folder / name
            if target.is_file() and target.read_text(encoding='utf-8') == value:
                continue
            fd, temporary = tempfile.mkstemp(prefix='.theme-wallpaper-', dir=folder)
            try:
                with os.fdopen(fd, 'w', encoding='utf-8') as output:
                    output.write(value)
                    output.flush()
                    os.fsync(output.fileno())
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)


def track_theme(control, name):
    data = read_json(preset_path(name))
    control['trackedTheme'] = {'name': name, 'fingerprint': version_fingerprint(data)}
    control['lastSavedAt'] = data.get('updatedAt') or now()


def autosave_active(control, data=None, allow_conflict=False):
    name = control.get('activeName', '')
    if control.get('transition'):
        return {'saved': False, 'message': 'A theme switch is in progress.'}
    if not name or control.get('session') or not preset_path(name).is_file():
        return {'saved': False, 'message': 'No active theme to autosave.'}
    existing = read_json(preset_path(name))
    validate(existing)
    tracked = control.get('trackedTheme') or {}
    if tracked.get('name') == name and tracked.get('fingerprint') != version_fingerprint(existing):
        if allow_conflict:
            checkpoint(freeze_wallpapers(data or current_desktop(), strict=False), control,
                       'Unsaved desktop before creating a separate theme', name=name)
            return {'saved': False, 'conflict': True}
        raise ValueError('This theme was edited in another file. Use Save changes to confirm the update, or New theme to preserve both versions.')
    if not OFFLINE and ipc('desktopPresetConfig', 'ready') != 'ok':
        return {'saved': False, 'retry': True, 'message': 'Waiting for the desktop to finish loading.'}
    if data is None:
        data = capture() if OFFLINE else capture(live=True, flush=False)
    if existing['version'] >= 3 and fingerprint(data) == fingerprint(existing):
        if tracked.get('name') != name:
            track_theme(control, name)
            atomic_write(CONTROL, control)
        persist_active_wallpaper_paths(existing)
        return {'saved': False, 'message': 'All visual changes are saved.'}
    save_preset(name, data, existing, autosaving=True)
    persist_active_wallpaper_paths(read_json(preset_path(name)))
    track_theme(control, name)
    atomic_write(CONTROL, control)
    return {'saved': True, 'message': 'Saved all visual changes to ' + name + '.', 'name': name}


def migrate_assets():
    control = load_control()
    count, missing = 0, []
    active = control.get('activeName', '')
    active_before = version_fingerprint(read_json(preset_path(active))) if active and preset_path(active).is_file() else ''
    for path in sorted(PRESETS.glob('*.json')):
        if path.is_symlink():
            raise ValueError('Preset may not be a symlink.')
        data = read_json(path)
        validate(data)
        missing.extend(p for p in data['wallpapers'].values() if p and not Path(p).is_file())
        frozen = freeze_wallpapers(data, strict=False)
        if frozen != data:
            checkpoint(data, control, 'Before preserving wallpaper for ' + path.stem, name=path.stem, kind='saved')
            atomic_write(path, frozen)
            count += 1
    name = control.get('activeName', '')
    tracked = control.get('trackedTheme') or {}
    if name and preset_path(name).is_file() and (not tracked or tracked.get('fingerprint') == active_before):
        track_theme(control, name)
        atomic_write(CONTROL, control)
    return {'message': 'Preserved wallpaper files for ' + str(count) + ' existing themes.', 'missingAssets': missing}


def current_desktop():
    """Read terminal edits and live models without ending an editing gesture."""
    if not OFFLINE:
        try:
            return capture(live=True, flush=False)
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return capture()


def merged(base, saved):
    """Old themes cannot remove keys introduced by later customizations."""
    result = copy.deepcopy(base)
    for key, value in saved.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merged(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def prepare_desktop(saved, current, sections=None, keep_apps=False):
    validate(saved)
    validate(current)
    selected = set(ALL_COMPONENTS if sections is None else sections)
    if not selected or selected - set(ALL_COMPONENTS):
        raise ValueError('Choose at least one valid desktop component.')
    target = copy.deepcopy(current)
    for key in SECTIONS:
        if key in selected:
            target['settings'][key] = copy.deepcopy(saved['settings'][key]) if saved['version'] >= 3 else merged(current['settings'][key], saved['settings'][key])
    if 'theme' in selected:
        target['visual'] = copy.deepcopy(saved.get('visual', current.get('visual', {})))
        # Legacy presets predate icon selection; they use the original Satin pack.
        target['settings']['theme']['iconPack'] = saved['settings']['theme'].get('iconPack', 'EvhOs-Satin')
    if keep_apps and 'apps' in current['settings']['dock']:
        target['settings']['dock']['apps'] = copy.deepcopy(current['settings']['dock']['apps'])
    target['settings']['dock']['editing'] = False
    if 'widgets' in selected:
        target['widgets'].update(copy.deepcopy(saved['widgets']))
    if 'wallpaper' in selected:
        for monitor, path in saved['wallpapers'].items():
            if path and not Path(path).is_file():
                raise ValueError('The saved wallpaper is missing. Select its wallpaper and save this theme, or explicitly exclude Wallpaper from the switch.')
            target['wallpapers'][monitor] = path
    # Recovery still works if an image was removed since the snapshot was made.
    for monitor, path in list(target['wallpapers'].items()):
        if path and not Path(path).is_file():
            target['wallpapers'].pop(monitor)
    validate(target)
    return target


def changed_components(current, baseline):
    a, b = canonical(current), canonical(baseline)
    result = [key for key in SECTIONS if a['settings'][key] != b['settings'][key]]
    if a.get('visual', {}) != b.get('visual', {}) and 'theme' not in result:
        result.append('theme')
    if a['widgets'] != b['widgets']:
        result.append('widgets')
    if a['wallpapers'] != b['wallpapers']:
        result.append('wallpaper')
    return result


def checkpoint(data, control, reason, name='', kind='desktop'):
    validate(data)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    folder = HISTORY / stamp
    atomic_write(folder / 'previous-desktop.json', data)
    atomic_write(folder / 'control.json', control)
    atomic_write(folder / 'metadata.json', {'id': stamp, 'createdAt': now(), 'reason': reason,
                                          'name': name or control.get('activeName', ''), 'kind': kind})
    return stamp


def history_snapshot(identifier):
    if not isinstance(identifier, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', identifier):
        raise ValueError('Invalid history entry.')
    folder = HISTORY / identifier
    path = folder / 'previous-desktop.json'
    if folder.is_symlink() or path.is_symlink():
        raise ValueError('History entries may not be symlinks.')
    data = read_json(path)
    validate(data)
    metadata = read_json(folder / 'metadata.json', {})
    control = read_json(folder / 'control.json', {})
    return data, metadata, control


def history_items():
    items = []
    for folder in sorted(HISTORY.glob('*'), reverse=True):
        if len(items) >= 20:
            break
        if not folder.is_dir() or not (folder / 'previous-desktop.json').is_file():
            continue
        try:
            data, meta, control = history_snapshot(folder.name)
            created = meta.get('createdAt', '')
            if not created:
                try:
                    created = dt.datetime.strptime(folder.name, '%Y%m%d-%H%M%S-%f').replace(tzinfo=dt.timezone.utc).isoformat()
                except ValueError:
                    pass
            items.append({'id': folder.name, 'createdAt': created,
                          'reason': meta.get('reason', 'Before a desktop change'),
                          'name': meta.get('name', control.get('activeName', 'Custom desktop')),
                          'kind': meta.get('kind', 'desktop')})
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return items


def component_description(data, key):
    if key == 'theme':
        theme = data['settings']['theme']
        name = {'EvhOs-Satin':'Satin', 'EvhOs-Facet':'Facet', 'EvhOs-Mono-Soft':'Mono Soft',
                'EvhOs-Pixel-Arcade':'Pixel Arcade', 'EvhOs-Type-Density':'Type Density', 'EvhOs-Sticker-Pals':'Sticker Pals'}.get(theme.get('iconPack'), 'Satin')
        return str(theme.get('activePreset', 'Custom colors')) + ' · ' + name + ' icons'
    if key == 'bar':
        bar = data['settings']['bar']
        return str(bar.get('position', 'top')).capitalize() + ' · ' + str(bar.get('width', 100)) + '% width'
    if key == 'dock':
        dock = data['settings']['dock']
        return (str(dock.get('position', 'bottom')).capitalize() + ' dock · ' + str(len(dock.get('apps', []))) + ' apps') if dock.get('enabled', True) else 'Dock hidden'
    if key == 'widgets':
        count = sum(len(layout) for layout in data['widgets'].values())
        return str(count) + (' widget' if count == 1 else ' widgets')
    paths = [data.get('wallpaperNames', {}).get(monitor, Path(path).name) for monitor, path in data['wallpapers'].items() if path]
    return ', '.join(paths) or 'Current wallpaper'


def review(name, source='preset'):
    if source == 'history':
        saved, metadata, control = history_snapshot(name)
        title = metadata.get('name') or control.get('activeName') or 'Previous desktop'
    else:
        saved = read_json(preset_path(name))
        validate(saved)
        title = name
    current = current_desktop()
    missing = [path for path in saved['wallpapers'].values() if path and not Path(path).is_file()]
    review_sections = [key for key in ALL_COMPONENTS if key != 'wallpaper' or not missing]
    target = prepare_desktop(saved, current, sections=review_sections, keep_apps=KEEP_APPS)
    changed = changed_components(target, current)
    missing = [path for path in saved['wallpapers'].values() if path and not Path(path).is_file()]
    return {'name': name, 'title': title, 'source': source, 'fingerprint': version_fingerprint(saved),
            'missingAssets': missing, 'currentApps': len(current['settings']['dock'].get('apps', [])),
            'savedApps': len(saved['settings']['dock'].get('apps', [])),
            'components': [{'key': key, 'label': COMPONENT_LABELS[key], 'changed': key in changed,
                            'before': component_description(current, key),
                            'after': 'Saved wallpaper needs relinking' if key == 'wallpaper' and missing else component_description(target, key)}
                           for key in ALL_COMPONENTS]}


def preset_summary(path):
    data = read_json(path)
    validate(data)
    missing = [p for p in data['wallpapers'].values() if p and not Path(p).is_file()]
    bar, dock = data['settings']['bar'], data['settings']['dock']
    colors = data['settings']['theme'].get('colors', {})
    wallpaper = next((p for p in data['wallpapers'].values() if p and Path(p).is_file()), '')
    preview = wallpaper if Path(wallpaper).suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp', '.bmp', '.avif') else ''
    preview_key = str(data.get('id') or path.stem)
    if not re.fullmatch(r'[A-Za-z0-9 _-]{1,96}', preview_key):
        preview_key = hashlib.sha256(preview_key.encode()).hexdigest()
    saved_preview = STATE / 'desktop-preset-previews' / (preview_key + '.png')
    if not preview and saved_preview.is_file():
        preview = str(saved_preview)
    preview_fallback = False
    if wallpaper and Path(wallpaper).suffix.lower() in ('.mp4', '.mkv', '.mov', '.webm'):
        asset_preview = asset_preview_path(wallpaper)
        if asset_preview.is_file():
            preview = str(asset_preview)
    preview_revision = str(Path(preview).stat().st_mtime_ns) if preview else ''
    def color(key, default):
        value = colors.get(key, default)
        return value if isinstance(value, str) and re.fullmatch(r'#[0-9a-fA-F]{3,8}', value) else default
    return {'name': path.stem, 'id': data.get('id', path.stem), 'wallpaper': wallpaper, 'preview': preview, 'previewRevision': preview_revision, 'previewFallback': preview_fallback,
            'iconPack': data['settings']['theme'].get('iconPack', 'EvhOs-Satin'),
            'barPosition': bar.get('position', 'top'), 'barWidth': bar.get('width', 100),
            'dockPosition': dock.get('position', 'bottom'), 'dockEnabled': dock.get('enabled', True),
            'widgetCount': sum(len(items) for items in data['widgets'].values()),
            'monitors': sorted(set(data['widgets']) | set(data['wallpapers'])),
            'updatedAt': data.get('updatedAt', ''), 'missingAssets': missing,
            'fingerprint': version_fingerprint(data), 'baseColor': color('base', '#16191e'),
            'accentColor': color('blue', '#8ba7d7'), 'surfaceColor': color('surface0', '#2b3038')}


def status():
    control = load_control()
    items, errors = [], []
    for path in sorted(PRESETS.glob('*.json'), key=lambda p: p.stem.casefold()):
        try:
            if path.is_symlink():
                raise ValueError('Preset is a symlink.')
            items.append(preset_summary(path))
        except (OSError, ValueError, KeyError, TypeError) as exc:
            errors.append(path.stem + ': ' + str(exc))
    current = current_desktop()
    name = control.get('activeName', '')
    if not name and not control.get('session'):
        for item in items:
            if item['fingerprint'] == fingerprint(current):
                name = item['name']
                break
    changed, saved_fingerprint = [], ''
    if name:
        try:
            baseline = read_json(preset_path(name))
            changed = changed_components(current, baseline)
            saved_fingerprint = version_fingerprint(baseline)
        except (OSError, ValueError, KeyError):
            changed = list(ALL_COMPONENTS)
    session = control.get('session')
    session_summary = None
    if session:
        sections = changed_components(current, session['baseline'])
        session_summary = {'name': session.get('name', ''), 'dirty': bool(sections), 'changedSections': sections,
                           'startedAt': session['startedAt'], 'isNew': not bool(session.get('name'))}
    return {'presets': items, 'activeName': name, 'modified': bool(changed), 'changedSections': changed,
            'activeFingerprint': saved_fingerprint, 'session': session_summary,
            'canUndo': bool(control.get('undo')), 'warnings': errors, 'history': history_items(),
            'sharedCustomizations': True, 'autosave': True, 'lastSavedAt': control.get('lastSavedAt', '')}


def save_preset(name, data, existing=None, capture_preview=True, autosaving=False):
    validate(data)
    if existing is None:
        ensure_unused(name)
    else:
        recent = [item for item in history_items() if item['kind'] == 'autosave' and item['name'] == name]
        coalesce = False
        if autosaving and recent and canonical(existing)['wallpapers'] == canonical(data)['wallpapers']:
            try:
                age = dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(recent[0]['createdAt'])
                coalesce = age.total_seconds() < 60
            except (ValueError, TypeError):
                pass
        if not coalesce:
            checkpoint(freeze_wallpapers(existing, strict=False), load_control(),
                       ('Before autosaving ' if autosaving else 'Before updating ') + name,
                       name=name, kind='autosave' if autosaving else 'saved')
    result = freeze_wallpapers(data)
    result.update(version=3, id=(existing or {}).get('id') or str(uuid.uuid4()),
                  createdAt=(existing or {}).get('createdAt') or now(), updatedAt=now())
    atomic_write(preset_path(name), result)
    # Keep a small preview for video wallpapers; source files are left untouched.
    if capture_preview and (existing is None or fingerprint(existing) != fingerprint(data)):
        for monitor in data['wallpapers']:
            preview = CACHE / 'wallpaper' / ('current_wallpaper_' + monitor + '.png')
            if preview.is_file() and preview.stat().st_size <= 12 * 1024 * 1024:
                import shutil
                key = str(result['id'])
                if not re.fullmatch(r'[A-Za-z0-9 _-]{1,96}', key):
                    key = hashlib.sha256(key.encode()).hexdigest()
                dest = STATE / 'desktop-preset-previews' / (key + '.png')
                try:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(preview, dest)
                except OSError:
                    pass  # A preview failure must never invalidate a saved theme.
                break


def execute(action, name='', target=''):
    control = load_control()
    session = control.get('session')
    if action == 'status':
        return status()
    if action == 'list':
        return [p.stem for p in sorted(PRESETS.glob('*.json'))]
    if action == 'review':
        return review(name, REVIEW_SOURCE)
    if action == 'history':
        return {'history': history_items()}
    if action == 'autosave':
        return autosave_active(control)
    if action == 'migrate-assets':
        return migrate_assets()
    if action == 'checkpoint':
        identifier = checkpoint(capture_for_save(), control, name or 'Manual desktop checkpoint')
        return {'message': 'Desktop checkpoint saved to History.', 'id': identifier}
    if action == 'finish':
        if session and session.get('name'):
            control['activeName'] = session['name']
        control['session'] = None
        atomic_write(CONTROL, control)
        return {'message': 'Editing finished. Your current desktop is unchanged.'}
    if action == 'begin':
        require_no_session(control)
        before = current_desktop()
        autosave_active(control, before)
        baseline = before
        if name:
            preset = read_json(preset_path(name))
            validate(preset)
            if name != control.get('activeName'):
                apply(prepare_desktop(preset, before), reason='Before previewing ' + name)
                baseline = current_desktop()
            else:
                baseline = preset
        control['session'] = {'name': name, 'startedAt': now(), 'before': before, 'baseline': baseline,
                              'previousActive': control.get('activeName', ''),
                              'presetFingerprint': version_fingerprint(read_json(preset_path(name))) if name else ''}
        atomic_write(CONTROL, control)
        return {'message': 'Editing ' + (name or 'a new look') + '. Saved themes change only when you save.'}
    if action == 'discard':
        if not session:
            raise ValueError('No editing session is open.')
        previous = current_desktop()
        apply(prepare_desktop(session['before'], previous, keep_apps=False), reason='Before discarding an editing session')
        control.update(activeName=session.get('previousActive', ''), session=None)
        atomic_write(CONTROL, control)
        return {'message': 'Previous desktop restored. Your discarded look is available in History.'}
    if action in ('save', 'update'):
        if action == 'update':
            name = name or (session or {}).get('name') or control.get('activeName', '')
            if not name:
                raise ValueError('Use New theme to give this desktop a name.')
            existing = read_json(preset_path(name))
            validate(existing)
            expected = EXPECTED or ((session or {}).get('presetFingerprint') if (session or {}).get('name') == name else '')
            if expected and version_fingerprint(existing) != expected:
                raise ValueError('This saved theme changed elsewhere. Refresh or use New theme to keep both versions.')
        else:
            ensure_unused(name)
            existing = None
        data = capture_for_save()
        if action == 'save':
            autosave_active(control, data, allow_conflict=True)
        if existing is not None and version_fingerprint(read_json(preset_path(name))) != version_fingerprint(existing):
            raise ValueError('The theme changed while saving. Use New theme to keep both versions.')
        save_preset(name, data, existing)
        persist_active_wallpaper_paths(read_json(preset_path(name)))
        control.update(activeName=name, session=None)
        track_theme(control, name)
        atomic_write(CONTROL, control)
        return {'message': ('Saved changes to ' + name + '. The previous version is in History.') if action == 'update'
                else ('Created and activated ' + name + '. Visual changes now save to this theme.')}
    if action in ('apply', 'restore'):
        if action == 'restore':
            data, metadata, saved_control = history_snapshot(name)
            active_name = metadata.get('name') or saved_control.get('activeName', '')
            reason = 'Before restoring a look from History'
        else:
            data = read_json(preset_path(name))
            active_name = name
            reason = 'Before switching to ' + name
        validate(data)
        if EXPECTED and version_fingerprint(data) != EXPECTED:
            raise ValueError('This saved look changed after the review. Review it again before switching.')
        current = current_desktop()
        prepared = prepare_desktop(data, current, SELECTED_SECTIONS, KEEP_APPS)
        saved_outgoing = autosave_active(control, current)
        if saved_outgoing.get('retry'):
            raise ValueError('The desktop is still loading. Try switching again shortly.')
        if action == 'apply' and name == control.get('activeName'):
            data = read_json(preset_path(name))
            prepared = prepare_desktop(data, current, SELECTED_SECTIONS, KEEP_APPS)
        before_control = copy.deepcopy(control)
        control['transition'] = {'from': control.get('activeName', ''), 'to': active_name, 'startedAt': now()}
        atomic_write(CONTROL, control)
        previous = None
        try:
            previous = apply(prepared, reason=reason)
            control['undo'] = {'desktop': previous, 'activeName': before_control.get('activeName', '')}
            control.update(activeName=active_name, session=None, transition=None)
            if active_name and preset_path(active_name).is_file():
                track_theme(control, active_name)
            atomic_write(CONTROL, control)
        except Exception:
            if previous is not None:
                apply(prepare_desktop(previous, current_desktop(), keep_apps=False), reason='Recovering an incomplete theme switch')
            atomic_write(CONTROL, before_control)
            raise
        return {'message': ('Restored the selected look. Saved themes are unchanged.' if action == 'restore'
                            else 'Switched to ' + name + '. Your previous desktop is in History.')}
    if action == 'undo':
        if not control.get('undo'):
            raise ValueError('There is no theme switch to undo.')
        undo = control['undo']
        autosave_active(control)
        apply(prepare_desktop(undo['desktop'], current_desktop(), keep_apps=False), reason='Before undoing a theme switch')
        control.update(activeName=undo.get('activeName', ''), undo=None, session=None)
        if control['activeName'] and preset_path(control['activeName']).is_file():
            track_theme(control, control['activeName'])
        atomic_write(CONTROL, control)
        return {'message': 'Restored the desktop from before the last switch.'}
    if action in ('rename', 'duplicate', 'delete'):
        require_no_session(control)
        source = preset_path(name)
        data = read_json(source)
        validate(data)
        if action == 'delete':
            checkpoint(data, control, 'Before removing ' + name, name=name, kind='saved')
            source.unlink()
            if control.get('activeName') == name:
                control['activeName'] = ''
        else:
            ensure_unused(target, name if action == 'rename' else '')
            if action == 'rename':
                if name != target:
                    atomic_write(preset_path(target), data)
                    source.unlink()
                if control.get('activeName') == name:
                    control['activeName'] = target
                    track_theme(control, target)
            else:
                save_preset(target, data, capture_preview=False)
        atomic_write(CONTROL, control)
        return {'message': {'rename': 'Theme renamed.', 'duplicate': 'Created a separate copy. Your desktop is unchanged.',
                            'delete': 'Removed from saved themes. A copy remains in History; your desktop is unchanged.'}[action]}
    raise ValueError('Unknown preset action.')


NOTIFICATION_TITLES = {
    'apply': 'Desktop theme switched',
    'restore': 'Desktop look restored',
    'checkpoint': 'Desktop checkpoint saved',
    'save': 'Preset saved',
    'update': 'Preset updated',
    'delete': 'Preset deleted',
    'rename': 'Preset renamed',
    'duplicate': 'Preset duplicated',
    'undo': 'Preset switch undone',
    'discard': 'Desktop changes discarded',
}


def notify_action(action, name='', target='', result=None, error=None):
    # Only explicit action completions produce notifications. Polling stays silent.
    if OFFLINE or (action not in NOTIFICATION_TITLES and not (action == 'begin' and error is not None)):
        return False
    if error is not None:
        title = 'Preset action failed'
        body = str(error)
        if len(body) > 360:
            body = body[:357] + '…'
        icon, lifetime = 'dialog-error', '8000'
    else:
        title = NOTIFICATION_TITLES[action]
        body = (result or {}).get('message', title + '.')
        if action == 'rename':
            body = '“' + name + '” was renamed to “' + target + '”.'
        elif action == 'duplicate':
            body = 'Created “' + target + '” from “' + name + '”.'
        elif action == 'delete':
            body = '“' + name + '” was deleted. Your desktop is unchanged.'
        icon, lifetime = 'preferences-desktop-theme', '5000'
    try:
        # Use the existing freedesktop notification service via notify-send.
        # Do not wait for dismissal or inherit the UI's output pipes.
        subprocess.Popen(['notify-send', '--app-name=Desktop presets', '--urgency=normal',
                          '--icon=' + icon, '--expire-time=' + lifetime, '--', title, body],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except (OSError, subprocess.SubprocessError):
        # Notification delivery must never turn a completed preset action into a failure.
        return False
    return True


def main():
    global OFFLINE, SELECTED_SECTIONS, KEEP_APPS, EXPECTED, REVIEW_SOURCE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--offline', action='store_true', help='Isolated file mode, for tests and shell recovery only.')
    parser.add_argument('--json', action='store_true', help='Return structured output for the UI.')
    parser.add_argument('--no-notify', action='store_true', help='Suppress notifications for automatic session cleanup.')
    parser.add_argument('--sections', default=None, help='Components to restore: theme,bar,dock,widgets,wallpaper')
    parser.add_argument('--with-apps', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--keep-apps', action='store_true', help='Explicitly keep current pins instead of restoring this theme’s pins.')
    parser.add_argument('--expected', default='', help='Fingerprint from review; refuse a changed saved theme.')
    parser.add_argument('--source', choices=['preset', 'history'], default='preset')
    parser.add_argument('action', choices=['list', 'status', 'review', 'history', 'autosave', 'migrate-assets', 'checkpoint', 'finish', 'begin', 'save', 'update', 'apply', 'restore', 'discard', 'undo', 'rename', 'duplicate', 'delete'])
    parser.add_argument('name', nargs='?', default='')
    parser.add_argument('target', nargs='?', default='')
    args = parser.parse_args()
    OFFLINE = args.offline
    SELECTED_SECTIONS = args.sections.split(',') if args.sections is not None else None
    KEEP_APPS = args.keep_apps
    EXPECTED = args.expected
    REVIEW_SOURCE = args.source
    try:
        if args.action in ('list', 'status', 'review', 'history'):
            result = execute(args.action, args.name, args.target)
        else:
            with operation_lock():
                result = execute(args.action, args.name, args.target)
        if args.json:
            print(json.dumps({'ok': True, 'result': result}, ensure_ascii=False, allow_nan=False))
        elif isinstance(result, list):
            print('\n'.join(result))
        else:
            print(result.get('message', json.dumps(result, ensure_ascii=False)))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        if args.json:
            print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False))
        else:
            print('Desktop preset error:', exc, file=sys.stderr)
        if not args.no_notify:
            notify_action(args.action, args.name, args.target, error=exc)
        return 1
    if not args.no_notify:
        notify_action(args.action, args.name, args.target, result=result)
    return 0


if __name__ == '__main__':
    sys.exit(main())
