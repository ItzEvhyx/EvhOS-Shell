#!/usr/bin/env python3
"""Read account limits through a short-lived Codex app-server session."""
import datetime
import json
import selectors
import subprocess
import sys
import time


def main():
    server = subprocess.Popen(['codex', 'app-server', '--listen', 'stdio://'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
    selector = selectors.DefaultSelector()
    selector.register(server.stdout, selectors.EVENT_READ)
    try:
        def send(value):
            server.stdin.write(json.dumps(value) + '\n')
            server.stdin.flush()
        def response(request_id):
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                if not selector.select(deadline - time.monotonic()): break
                line = server.stdout.readline()
                if not line: raise RuntimeError('Codex usage service stopped')
                try: item = json.loads(line)
                except json.JSONDecodeError: continue
                if item.get('id') != request_id: continue
                if 'error' in item: raise RuntimeError(item['error'].get('message', 'Could not read usage'))
                return item.get('result') or {}
            raise TimeoutError('Usage refresh timed out')
        send({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'serpantinum_usage', 'title': 'Serpantinum usage', 'version': '1.0'}}})
        response(1)
        send({'method': 'initialized', 'params': {}})
        send({'id': 2, 'method': 'account/rateLimits/read', 'params': {}})
        result = response(2)
        snapshot = (result.get('rateLimitsByLimitId') or {}).get('codex') or result.get('rateLimits') or {}
        print(json.dumps({'snapshot': snapshot, 'updated': datetime.datetime.now().strftime('%I:%M %p').lstrip('0'), 'error': ''}))
    finally:
        selector.close()
        server.terminate()
        try: server.wait(timeout=3)
        except subprocess.TimeoutExpired: server.kill(); server.wait()


if __name__ == '__main__':
    try: main()
    except Exception as error: print(json.dumps({'error': str(error)})); sys.exit(1)
