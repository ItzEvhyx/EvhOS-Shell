#!/usr/bin/env python3
"""Restore checked icon lookup and reset recycled image state after updates."""
import os
from pathlib import Path
import sys
import tempfile

base = Path.home() / '.local/share/serpantinum/src/quickshell'
changes = {
    base / 'launcher/Launcher.qml': [
        ('let resolved = Quickshell.iconPath(ic) || Quickshell.iconPath(baseName);', 'let resolved = Quickshell.iconPath(ic, true) || Quickshell.iconPath(baseName, true); // local checked icons'),
        ('                                                    return "image://icon/" + baseName;', '                                                    return ""; // local checked icons'),
        ('                                                onStatusChanged: {\n                                                    if (status === Image.Error) {\n                                                        failedLoad = true;\n                                                    }\n                                                }', '                                                onSourceChanged: failedLoad = false // local recycled icon reset\n                                                onStatusChanged: failedLoad = status === Image.Error'),
    ],
    base / 'dock/DockAppButton.qml': [
        ('import QtQuick.Layouts\n', 'import QtQuick.Layouts\nimport Quickshell // local checked icons\n'),
        ('                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;', '                    return ic.startsWith("/") ? "file://" + ic : Quickshell.iconPath(ic, true); // local checked icons'),
        ('                onStatusChanged: {\n                    if (status === Image.Error) {\n                        failedLoad = true;\n                    }\n                }', '                onSourceChanged: failedLoad = false // local recycled icon reset\n                onStatusChanged: failedLoad = status === Image.Error'),
    ],
    base / 'dock/DockRunningButton.qml': [
        ('import QtQuick.Layouts\n', 'import QtQuick.Layouts\nimport Quickshell // local checked icons\n'),
        ('                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;', '                    return ic.startsWith("/") ? "file://" + ic : Quickshell.iconPath(ic, true); // local checked icons'),
        ('                onStatusChanged: {\n                    if (status === Image.Error) failedLoad = true;\n                }', '                onSourceChanged: failedLoad = false // local recycled icon reset\n                onStatusChanged: failedLoad = status === Image.Error'),
    ],
    base / 'dock/DockWindowApps.qml': [
        ('            if (!ent && typeof AppMatcher !== "undefined" && rawApp !== "") ent = AppMatcher.entry(rawApp);', '            if (!ent && typeof AppMatcher !== "undefined" && rawApp !== "") ent = AppMatcher.entry(AppMatcher.resolve(rawApp)); // local app matching'),
    ],
}
try:
    pending = []
    for path, edits in changes.items():
        source = path.read_text()
        updated = source
        for before, after in edits:
            if after in updated: continue
            if updated.count(before) != 1: raise ValueError(f'{path.name} icon logic changed; fix needs manual review')
            updated = updated.replace(before, after, 1)
        if updated != source: pending.append((path, updated))
    for path, content in pending:
        fd, temp = tempfile.mkstemp(prefix='.' + path.stem + '.', suffix='.qml', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as f: f.write(content)
            os.chmod(temp, path.stat().st_mode & 0o777)
            os.replace(temp, path)
        finally:
            if os.path.exists(temp): os.unlink(temp)
    sys.exit(10 if pending else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum icons: {exc}', file=sys.stderr)
    sys.exit(1)
