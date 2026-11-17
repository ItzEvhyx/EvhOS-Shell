#!/usr/bin/env python3
"""Run the snapshot's portable integrity, backend, installer and restore checks."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'

def run(*args):
    print('+', ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True)

run(sys.executable, ROOT/'tools/check-snapshot.py')
for test in sorted((ROOT/'tests').glob('test-*.py')):
    run(sys.executable, test)
for script in [ROOT/'install.sh', *sorted((ROOT/'snapshot').rglob('*.sh'))]:
    run('bash', '-n', script)
run('bash', ROOT/'tests/test-install-plan.sh')
luac = shutil.which('luac') or shutil.which('luac5.4')
if luac:
    for script in sorted((ROOT/'snapshot/home/.config/hypr').rglob('*.lua')):
        run(luac, '-p', script)
else:
    print('SKIP Lua syntax checks: install Lua 5.4.')
print('All available checks passed. Graphical session behavior still requires a live Hyprland session.')
