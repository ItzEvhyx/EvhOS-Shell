#!/usr/bin/env python3
"""Restore the customized calendar, ASCII weather card and usage panel."""
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
    # Keep weather-card dependencies with the persistent calendar customization.
    weather_source = home / '.config/hypr/scripts/serpantinum-ascii-weather'
    for name in ('AsciiWeatherCard.qml', 'AsciiWeatherArt.qml', 'WeatherMatrixText.qml'):
        src = weather_source / name
        target = base / 'calendar' / name
        if src.is_file():
            text = src.read_text()
            if not target.exists() or target.read_text() != text:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text)
                changed = True
    clock_source = home / '.config/hypr/scripts/serpantinum-clock-badge.qml'
    clock_target = base / 'bar/faces/timedate/BadgeFace.qml'
    if clock_source.is_file():
        text = clock_source.read_text()
        if not clock_target.exists() or clock_target.read_text() != text:
            clock_target.parent.mkdir(parents=True, exist_ok=True)
            clock_target.write_text(text)
            changed = True
    for name, relative in (
        ('serpantinum-balanced-topbar.qml', 'bar/TopBar.qml'),
        ('serpantinum-music-cover.qml', 'media/MusicCover.qml'),
        ('serpantinum-compact-media.qml', 'bar/faces/media/MediaFace.qml'),
        ('serpantinum-throughput-wifi.qml', 'bar/faces/wifi/WifiFace.qml'),
        ('serpantinum-connected-wallpapers.qml', 'popouts/DesktopMenu.qml'),
    ):
        src = home / '.config/hypr/scripts' / name
        target = base / relative
        if src.is_file():
            text = src.read_text()
            if not target.exists() or target.read_text() != text:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text)
                changed = True
    registry = base / 'qmldir' 
    text = registry.read_text()
    for name in ('CodexUsageDashboard', 'CodexActionButton'):
        entry = f'{name} 1.0 {name}.qml\n'
        if entry not in text:
            text += '\n' + entry
            changed = True
    for name in ('AsciiWeatherCard', 'AsciiWeatherArt', 'WeatherMatrixText'):
        entry = f'{name} 1.0 calendar/{name}.qml\n'
        if entry not in text:
            text += '\n' + entry
            changed = True
    if registry.read_text() != text: registry.write_text(text)
    sys.exit(10 if changed else 0)
except OSError as error:
    print(f'Serpantinum calendar: {error}', file=sys.stderr)
    sys.exit(1)
