#!/usr/bin/env python3
"""Notify when external power changes, without announcing the initial state."""
import os
from pathlib import Path
import subprocess
import time

POWER_DIR = Path(os.environ.get('POWER_SUPPLY_DIR', '/sys/class/power_supply'))


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ''


def power_state(directory=POWER_DIR):
    try:
        devices = list(directory.iterdir())
    except OSError:
        return None, None
    batteries = [d for d in devices if read(d / 'type') == 'Battery' and read(d / 'present') != '0']
    adapters = [d for d in devices if read(d / 'type') in ('Mains', 'USB', 'USB_C', 'USB_PD') and read(d / 'online') in ('0', '1')]
    if not batteries or not adapters:
        return None, None
    capacities = [int(v) for d in batteries if (v := read(d / 'capacity')).isdigit()]
    return any(read(d / 'online') == '1' for d in adapters), (round(sum(capacities) / len(capacities)) if capacities else None)


def notify(connected, percentage):
    title = 'Charger connected' if connected else 'Charger disconnected'
    body = 'Laptop is connected to power' if connected else 'Laptop is running on battery'
    if percentage is not None:
        body += f' · {percentage}% battery'
    subprocess.run(['notify-send', '-a', 'Power', '-i', 'battery-good-charging-symbolic' if connected else 'battery-good-symbolic', title, body], check=False)


def main():
    previous = None
    while True:
        connected, percentage = power_state()
        if connected is not None:
            if previous is not None and connected != previous:
                notify(connected, percentage)
            previous = connected
        time.sleep(2)


if __name__ == '__main__':
    main()
