#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'snapshot/shell/src/scripts/desktop-presets.py'

class DesktopPresetsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.state = self.home / '.local/state/serpantinum'
        self.settings = self.home / '.config/serpantinum/settings.json'
        self.wall = self.home / 'wall paper.png'
        self.wall.write_bytes(b'image')
        self.write(self.settings, {'theme': {'colors': {'base': '#000'}}, 'bar': {'position': 'top'}, 'dock': {'apps': ['one']}, 'general': {'language': 'en'}})
        self.layout = self.state / 'widgets/eDP-1/layout.json'
        self.write(self.layout, [{'wType': 'clock', 'wX': 42}])
        cache = self.home / '.cache/serpantinum/wallpaper/current_eDP-1'
        cache.parent.mkdir(parents=True)
        cache.write_text(str(self.wall))
        self.env = dict(os.environ, HOME=str(self.home))
        for k in ('QS_STATE_DIR', 'QS_CACHE_DIR', 'QS_SETTINGS', 'MAIN_QML'): self.env.pop(k, None)
    def write(self, path, obj):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(obj))
    def run_cli(self, *args, ok=True):
        p = subprocess.run(['python3', str(SCRIPT), *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode == 0, ok, p.stderr)
        return p
    def test_save_apply_and_backup(self):
        self.run_cli('save', 'My desktop')
        self.assertIn('My desktop', self.run_cli('list').stdout)
        self.run_cli('save', 'My desktop', ok=False)
        self.write(self.settings, {'theme': {}, 'bar': {}, 'dock': {}, 'general': {'language': 'fr'}})
        self.write(self.layout, [])
        self.run_cli('apply', 'My desktop', '--offline')
        settings = json.loads(self.settings.read_text())
        self.assertEqual(settings['general']['language'], 'fr')
        self.assertEqual(settings['dock']['apps'], ['one'])
        self.assertEqual(json.loads(self.layout.read_text())[0]['wX'], 42)
        backup = next((self.state / 'desktop-preset-backups').iterdir())
        self.assertEqual(json.loads((backup / '0.bak').read_text())['general']['language'], 'fr')
    def test_missing_wallpaper_and_invalid_monitor_do_not_modify(self):
        self.run_cli('save', 'Safe')
        before = self.settings.read_bytes()
        self.wall.unlink()
        self.run_cli('apply', 'Safe', '--offline', ok=False)
        self.assertEqual(self.settings.read_bytes(), before)
        preset = self.state / 'desktop-presets/Safe.json'
        obj = json.loads(preset.read_text())
        obj['widgets']['../escape'] = []
        self.write(preset, obj)
        self.run_cli('apply', 'Safe', '--offline', ok=False)
        self.assertEqual(self.settings.read_bytes(), before)
    def test_ipc_failure_restores_files(self):
        self.run_cli('save', 'Safe')
        self.write(self.layout, [])
        self.write(self.settings, {'theme': {}, 'bar': {}, 'dock': {}, 'general': {'language': 'fr'}})
        before_settings, before_layout = self.settings.read_bytes(), self.layout.read_bytes()
        bindir = self.home / 'bin'
        bindir.mkdir()
        fake = bindir / 'quickshell'
        fake.write_text('#!/bin/sh\ncase "$*" in *"widgets-eDP-1 reload"*) exit 1;; esac\nexit 0\n')
        fake.chmod(0o755)
        self.env['PATH'] = str(bindir) + os.pathsep + self.env['PATH']
        self.run_cli('apply', 'Safe', ok=False)
        self.assertEqual(self.settings.read_bytes(), before_settings)
        self.assertEqual(self.layout.read_bytes(), before_layout)

    def test_bad_name(self):
        self.run_cli('save', '../escape', ok=False)

if __name__ == '__main__': unittest.main()
