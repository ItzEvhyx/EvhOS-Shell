#!/usr/bin/env python3
"""Run the Lua used by the real QML focus handoff against compositor state fixtures."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT/'snapshot/shell/src/quickshell/singletons/system/WorkspaceOverview.qml').read_text()
EXPRESSION = SOURCE.split('let code =', 1)[1].split('switchProcess.command', 1)[0]
CODE = ''.join('7' if token == 'String(target)' else json.loads(token)
               for token in re.findall(r'"(?:[^"\\]|\\.)*"|String\(target\)', EXPRESSION))
LUA = shutil.which('lua') or shutil.which('lua5.4')


@unittest.skipUnless(LUA, 'Lua 5.4 is required')
class WorkspaceSwitchTest(unittest.TestCase):
    def run_case(self, mapped=False, active=2, special=False, blocked=False):
        fixture = '''
local mapped, active, special, blocked = %s, %d, %s, %s
local count, toggles = 0, 0
hl = {
 get_layers = function(opts) assert(opts.namespace == 'serpantinum-workspace-overview'); return {{mapped=mapped}} end,
 get_active_special_workspace = function() if special then return {name='special:scratchpad'} end end,
 get_active_workspace = function() return {id=active} end,
 dsp = {workspace={toggle_special=function(name) assert(name=='scratchpad'); return {special=true} end},
        focus=function(opts) return {workspace=tonumber(opts.workspace)} end},
 dispatch = function(opts) if opts.special then toggles=toggles+1 else count=count+1; if not blocked then active=opts.workspace end end end
}
local ok, err = pcall(function() %s end)
print(ok, count, toggles, active, err or '')
''' % (str(mapped).lower(), active, str(special).lower(), str(blocked).lower(), CODE)
        return subprocess.run([LUA, '-'], input=fixture, text=True, capture_output=True, check=True).stdout.strip().split('\t')

    def test_waits_for_layer_unmap_without_changing_focus(self):
        result = self.run_case(mapped=True)
        self.assertEqual(result[:4], ['false', '0', '0', '2'])
        self.assertIn('OVERVIEW_WAIT_FOR_UNMAP', result[-1])

    def test_switches_after_unmap(self):
        self.assertEqual(self.run_case()[:4], ['true', '1', '0', '7'])

    def test_current_workspace_does_not_toggle_back(self):
        self.assertEqual(self.run_case(active=7)[:4], ['true', '0', '0', '7'])

    def test_closes_special_workspace_before_switching(self):
        self.assertEqual(self.run_case(special=True)[:4], ['true', '1', '1', '7'])

    def test_reports_failed_focus(self):
        result = self.run_case(blocked=True)
        self.assertEqual(result[:4], ['false', '1', '0', '2'])
        self.assertIn('Selected workspace did not become active', result[-1])


if __name__ == '__main__':
    unittest.main()
