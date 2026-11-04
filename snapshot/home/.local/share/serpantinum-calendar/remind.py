#!/usr/bin/env python3
"""Show a desktop notification once for each calendar event on its date."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'serpantinum/calendar-events.json'
state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'serpantinum/calendar-reminders.json'
today = datetime.date.today().isoformat()
try:
    events = json.loads(config.read_text())
except (OSError, ValueError):
    raise SystemExit(0)
try:
    sent = json.loads(state.read_text())
except (OSError, ValueError):
    sent = {}
event = events.get(today)
if not isinstance(event, dict) or not event.get('name'):
    raise SystemExit(0)
# A date is notified once, even if the event is edited later that day.
if sent.get('date') == today:
    raise SystemExit(0)
result = subprocess.run(['notify-send', '--app-name=Calendar', '--icon=x-office-calendar',
                         'Today: ' + event['name'], event.get('details', '')], check=False)
if result.returncode == 0:
    state.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile('w', dir=state.parent, delete=False) as f:
        json.dump({'date': today}, f)
        temp = f.name
    os.replace(temp, state)
