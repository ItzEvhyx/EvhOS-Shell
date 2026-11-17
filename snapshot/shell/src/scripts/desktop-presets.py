#!/usr/bin/env python3
"""Transactional desktop presets and recoverable customization sessions."""
import argparse
import copy
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
    if not isinstance(data, dict) or data.get('version') not in (1, 2):
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
    # Reject non-finite numbers even in nested widget properties.
    json.dumps(data, allow_nan=False)


def canonical(data):
    result = copy.deepcopy({key: data[key] for key in ('settings', 'widgets', 'wallpapers')})
    theme = result['settings']['theme']
    if theme.get('matugen') or theme.get('activePreset') == 'Matugen':
        theme.pop('colors', None)  # Generated colors are not a user edit.
    result['settings']['dock'].pop('editing', None)
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


def capture(live=False):
    if live:
        expect_ok('redactor', 'flush')
    settings = ipc_json('desktopPresetConfig', 'get', expected_type=dict) if live else read_json(SETTINGS)
    data = {'version': 2, 'settings': {k: copy.deepcopy(settings[k]) for k in SECTIONS}, 'widgets': {}, 'wallpapers': {}}
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


def preset_summary(path):
    data = read_json(path)
    validate(data)
    missing = [p for p in data['wallpapers'].values() if p and not Path(p).is_file()]
    bar, dock = data['settings']['bar'], data['settings']['dock']
    return {'name': path.stem, 'id': data.get('id', path.stem), 'wallpaper': next((p for p in data['wallpapers'].values() if p), ''),
            'barPosition': bar.get('position', 'top'), 'barWidth': bar.get('width', 100),
            'dockPosition': dock.get('position', 'bottom'), 'dockEnabled': dock.get('enabled', True),
            'widgetCount': sum(len(items) for items in data['widgets'].values()),
            'monitors': sorted(set(data['widgets']) | set(data['wallpapers'])),
            'updatedAt': data.get('updatedAt', ''), 'missingAssets': missing}


def status():
    control = load_control()
    items, errors = [], []
    for path in sorted(PRESETS.glob('*.json'), key=lambda p: p.stem.casefold()):
        try:
            if path.is_symlink():
                raise ValueError('Preset is a symlink.')
            items.append(preset_summary(path))
        except (OSError, ValueError, KeyError) as exc:
            errors.append(path.stem + ': ' + str(exc))
    current = capture()
    name = control.get('activeName', '')
    if not name and not control.get('session'):
        for item in items:
            if fingerprint(read_json(preset_path(item['name']))) == fingerprint(current):
                name = item['name']
                break
    modified = False
    if name:
        try:
            modified = fingerprint(current) != fingerprint(read_json(preset_path(name)))
        except (OSError, ValueError):
            modified = True
    session = control.get('session')
    session_summary = None
    if session:
        changed = [key for key in ('settings', 'widgets', 'wallpapers') if canonical(current)[key] != canonical(session['baseline'])[key]]
        sections = [key for key in SECTIONS if canonical(current)['settings'][key] != canonical(session['baseline'])['settings'][key]]
        if 'widgets' in changed:
            sections.append('widgets')
        if 'wallpapers' in changed:
            sections.append('wallpaper')
        session_summary = {'name': session.get('name', ''), 'dirty': bool(changed), 'changedSections': sections,
                           'startedAt': session['startedAt'], 'isNew': not bool(session.get('name'))}
    return {'presets': items, 'activeName': name, 'modified': modified, 'session': session_summary,
            'canUndo': bool(control.get('undo')), 'warnings': errors}


def write_live(data, monitors):
    expect_ok('desktopPresetConfig', 'apply', json.dumps(data['settings']))
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
    wait_until(lambda: ipc('desktopPresetConfig', 'ready') == 'ok' and all(read_json(SETTINGS).get(k) == data['settings'][k] for k in SECTIONS),
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


def apply(data):
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
    previous = capture(live=not OFFLINE)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    backup = STATE / 'desktop-preset-backups' / stamp
    atomic_write(backup / 'previous-desktop.json', previous)
    atomic_write(backup / 'control.json', load_control())
    monitors = []
    started = []
    try:
        if OFFLINE:
            settings = read_json(SETTINGS)
            settings.update(data['settings'])
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
                    expect_ok('desktopPresetConfig', 'apply', json.dumps(previous['settings']))
                    wait_until(lambda: ipc('desktopPresetConfig', 'ready') == 'ok' and
                               all(read_json(SETTINGS).get(k) == previous['settings'][k] for k in SECTIONS),
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


def save_preset(name, data, existing=None):
    validate(data)
    result = copy.deepcopy(data)
    result.update(version=2, id=(existing or {}).get('id') or str(uuid.uuid4()),
                  createdAt=(existing or {}).get('createdAt') or now(), updatedAt=now())
    atomic_write(preset_path(name), result)


def require_no_session(control):
    if control.get('session'):
        raise ValueError('Save or discard your editing session before switching presets.')


def execute(action, name='', target=''):
    control = load_control()
    session = control.get('session')
    if action == 'status':
        return status()
    if action == 'list':
        return [p.stem for p in sorted(PRESETS.glob('*.json'))]
    if action in ('apply', 'begin', 'undo'):
        require_no_session(control)
    if action == 'begin':
        before = capture(live=not OFFLINE)
        baseline = before
        if name:
            preset = read_json(preset_path(name))
            validate(preset)
            if name != control.get('activeName'):
                apply(preset)
                baseline = capture(live=not OFFLINE)
            else:
                # Keep ordinary settings changes when customizing the already-active preset.
                baseline = preset
        control['session'] = {'name': name, 'startedAt': now(), 'before': before, 'baseline': baseline,
                              'previousActive': control.get('activeName', ''),
                              'presetFingerprint': fingerprint(read_json(preset_path(name))) if name else ''}
        atomic_write(CONTROL, control)
        return {'message': 'Editing ' + (name or 'new preset') + '. Your saved preset is unchanged.'}
    if action == 'discard':
        if not session:
            raise ValueError('No editing session is open.')
        apply(session['before'])
        control['activeName'] = session.get('previousActive', '')
        control['session'] = None
        atomic_write(CONTROL, control)
        return {'message': 'Changes discarded. Your previous desktop was restored.'}
    if action in ('save', 'update'):
        if action == 'update':
            if not session or not session.get('name'):
                raise ValueError('Choose a name with Save as new.')
            name = session['name']
            existing = read_json(preset_path(name))
            if fingerprint(existing) != session['presetFingerprint']:
                raise ValueError('The saved preset changed elsewhere. Use Save as new to keep your work.')
        else:
            ensure_unused(name)
            existing = None
        data = capture_for_save()
        save_preset(name, data, existing)
        control.update(activeName=name, session=None)
        atomic_write(CONTROL, control)
        return {'message': 'Saved ' + name + '. Editing finished.'}
    if action == 'apply':
        data = read_json(preset_path(name))
        previous = apply(data)
        control['undo'] = {'desktop': previous, 'activeName': control.get('activeName', '')}
        control['activeName'] = name
        atomic_write(CONTROL, control)
        return {'message': 'Applied ' + name + '. You can undo this switch.'}
    if action == 'undo':
        if not control.get('undo'):
            raise ValueError('There is no preset switch to undo.')
        undo = control['undo']
        apply(undo['desktop'])
        control.update(activeName=undo.get('activeName', ''), undo=None)
        atomic_write(CONTROL, control)
        return {'message': 'Restored the desktop from before the last preset switch.'}
    if action in ('rename', 'duplicate', 'delete'):
        require_no_session(control)
        source = preset_path(name)
        data = read_json(source)
        validate(data)
        if action == 'delete':
            # Keep deletion recoverable without turning the preset list into a recycle bin.
            stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
            atomic_write(STATE / 'desktop-preset-backups' / ('deleted-' + stamp) / (name + '.json'), data)
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
            else:
                save_preset(target, data)
        atomic_write(CONTROL, control)
        return {'message': {'rename': 'Preset renamed.', 'duplicate': 'Preset duplicated.', 'delete': 'Preset deleted; the desktop is unchanged.'}[action]}
    raise ValueError('Unknown preset action.')


NOTIFICATION_TITLES = {
    'apply': 'Preset applied',
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
    global OFFLINE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--offline', action='store_true', help='Isolated file mode, for tests and shell recovery only.')
    parser.add_argument('--json', action='store_true', help='Return structured output for the UI.')
    parser.add_argument('--no-notify', action='store_true', help='Suppress notifications for automatic session cleanup.')
    parser.add_argument('action', choices=['list', 'status', 'begin', 'save', 'update', 'apply', 'discard', 'undo', 'rename', 'duplicate', 'delete'])
    parser.add_argument('name', nargs='?', default='')
    parser.add_argument('target', nargs='?', default='')
    args = parser.parse_args()
    OFFLINE = args.offline
    try:
        if args.action in ('list', 'status'):
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
