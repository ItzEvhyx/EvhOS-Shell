#!/usr/bin/env python3
"""Restore the customized calendar, weather ring and usage panel."""
from pathlib import Path
import sys
home = Path.home()
base = home / '.local/share/serpantinum/src/quickshell'
source = home / '.config/serpantinum/codex-usage'
try:
    changed = False
    for src, target in [(home / '.config/hypr/scripts/serpantinum-calendar-custom.qml', base / 'calendar/CalendarPopup.qml'), (source / 'CodexUsageDashboard.qml', base / 'CodexUsageDashboard.qml'), (source / 'CodexActionButton.qml', base / 'CodexActionButton.qml')]:
        text = src.read_text()
        if not target.exists() or target.read_text() != text:
            target.write_text(text)
            changed = True
    registry = base / 'qmldir'
    text = registry.read_text()
    for name in ('CodexUsageDashboard', 'CodexActionButton'):
        entry = f'{name} 1.0 {name}.qml\n'
        if entry not in text:
            text += '\n' + entry
            changed = True
    if registry.read_text() != text: registry.write_text(text)
    sys.exit(10 if changed else 0)
except OSError as error:
    print(f'Serpantinum calendar: {error}', file=sys.stderr)
    sys.exit(1)
