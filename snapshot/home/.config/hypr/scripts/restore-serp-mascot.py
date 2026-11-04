#!/usr/bin/env python3
"""Restore the notification-center mascot; exit 10 only when changed."""
import os
from pathlib import Path
import re
import sys
import tempfile

home = Path.home()
path = home / '.local/share/serpantinum/src/quickshell/reusables/display/NotificationBox.qml'
image = home / 'Documents/OS_Images/notif_center_avatar.png'
try:
    if not image.is_file():
        raise ValueError(f'mascot image missing: {image}')
    source = path.read_text()
    pattern = re.compile(r'(\bid: pushyImg\b.*?\bvisible: root\.showEmptyGraphic)', re.S)
    matches = list(pattern.finditer(source))
    if len(matches) != 1:
        raise ValueError('empty notification graphic changed; mascot needs manual review')
    block = matches[0].group()
    block, sources = re.subn(r'(?m)^(\s*source:\s*).+$', lambda m: m.group(1) + '"' + image.as_uri() + '"', block)
    block, gifs = re.subn(r'(?m)^(\s*isGif:\s*).+$', r'\g<1>false', block)
    if sources != 1 or gifs != 1:
        raise ValueError('empty notification graphic properties changed; mascot needs manual review')
    updated = source[:matches[0].start()] + block + source[matches[0].end():]
    if updated == source:
        sys.exit(0)
    fd, temp = tempfile.mkstemp(prefix='.NotificationBox.', suffix='.qml', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(updated)
        os.chmod(temp, path.stat().st_mode & 0o777)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    sys.exit(10)
except (OSError, ValueError) as exc:
    print(f'Serpantinum mascot: {exc}', file=sys.stderr)
    sys.exit(1)
