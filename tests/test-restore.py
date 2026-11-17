#!/usr/bin/env python3
"""Verify real restoration, home substitution and second-pass backups in a temporary home."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.geteuid() == 0, 'Restore intentionally refuses root')
class RestoreTest(unittest.TestCase):
    def test_preview_restore_and_backup(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)/'home'
            command = [sys.executable, str(ROOT/'restore.py'), '--home', str(home)]
            subprocess.run(command, check=True, capture_output=True)
            self.assertFalse(home.exists(), 'Preview must not write files')
            subprocess.run(command+['--apply'], check=True, capture_output=True)
            self.assertTrue((home/'.local/bin/serpantinum').resolve().is_file())
            current = home/'.cache/serpantinum/wallpaper/current_eDP-1'
            self.assertTrue(Path(current.read_text().strip()).is_file())
            self.assertTrue(current.read_text().startswith(str(home)))
            config = home/'.config/serpantinum/settings.json'
            config.write_text('{"restore_test": true}\n')
            subprocess.run(command+['--apply'], check=True, capture_output=True)
            backups = list((home/'.local/state/evhos-backups').glob('*/.config/serpantinum/settings.json'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(json.loads(backups[0].read_text()), {'restore_test': True})
            self.assertNotIn('restore_test', json.loads(config.read_text()))
            source_home = json.loads((ROOT/'snapshot/metadata.json').read_text())['source_home']
            for path in home.rglob('*'):
                if 'evhos-backups' in path.parts:
                    continue
                if path.is_symlink():
                    self.assertNotIn(source_home, os.readlink(path))
                elif path.is_file():
                    try:
                        text = path.read_text()
                    except (UnicodeDecodeError, OSError):
                        continue
                    self.assertNotIn(source_home, text, str(path))


if __name__ == '__main__':
    unittest.main()
