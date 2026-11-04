#!/usr/bin/env python3
"""Copy a clipboard image into the notes attachment directory, or request normal text paste."""
import os
from pathlib import Path
import subprocess
import sys
import uuid


def main():
    try:
        types = subprocess.run(['wl-paste', '--list-types'], capture_output=True, text=True, timeout=5, check=True).stdout.splitlines()
        if 'image/png' not in types:
            print('TEXT')
            return
        image = subprocess.run(['wl-paste', '--no-newline', '--type', 'image/png'], capture_output=True, timeout=15, check=True).stdout
        if not image.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('Clipboard image is not a PNG')
        directory = Path(sys.argv[1]) / 'note-images'
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        path = directory / (uuid.uuid4().hex + '.png')
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as output:
            output.write(image)
        print('IMAGE:' + path.as_uri())
    except (OSError, subprocess.SubprocessError, ValueError, IndexError) as error:
        print('ERROR:' + str(error))
        sys.exit(1)


if __name__ == '__main__':
    main()
