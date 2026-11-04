#!/usr/bin/env python3
"""Keep dock workspace state synchronized with Hyprland across updates."""
import os
from pathlib import Path
import sys
import tempfile

path = Path.home() / '.local/share/serpantinum/src/quickshell/dock/DockWindowState.qml'
marker = 'id: localHyprDockPoller'
old_fullscreen = '    readonly property bool isFullscreenActive: isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen'
previous_fix = '''    // An inactive fullscreen window can remain the last focused toplevel after
    // switching to an empty workspace. It must not hide that workspace's dock.
    readonly property bool isFullscreenActive: isHyprland && !isWorkspaceBusy
        ? false : (isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen)'''
new_fullscreen = '''    readonly property bool isFullscreenActive: isHyprland && localHyprDockState !== null
        ? localHyprDockState.fullscreen : (isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen)'''
poll = '''    // Query the compositor directly: the Quickshell Hyprland workspace model can
    // retain the previously focused workspace after a compositor update.
    property var localHyprDockState: null
    // Coalesce event bursts and retry if a compositor query is still running.
    Timer {
        id: localHyprDockRefresh
        interval: 20
        onTriggered: {
            if (localHyprDockPoller.running) restart();
            else localHyprDockPoller.running = true;
        }
    }
    Connections {
        target: dockWindow.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (!event || !event.name) return;
            if (["workspace", "workspacev2", "focusedmon", "focusedmonv2", "openwindow", "closewindow", "movewindow", "movewindowv2", "activespecial", "activespecialv2", "fullscreen"].includes(event.name))
                localHyprDockRefresh.restart();
        }
    }
    Timer {
        interval: 750
        running: dockWindow.isHyprland
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!localHyprDockPoller.running) localHyprDockPoller.running = true
    }
    Process {
        id: localHyprDockPoller
        command: ["bash", "-c", "{ hyprctl -j monitors && hyprctl -j workspaces; } | jq -s ."]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let mon = data[0].find(m => m.name === dockWindow.myOutput);
                    if (!mon) return;
                    let ws = data[1].find(w => w.id === mon.activeWorkspace.id);
                    let special = mon.specialWorkspace && mon.specialWorkspace.id
                        ? data[1].find(w => w.id === mon.specialWorkspace.id) : null;
                    if (!ws) return;
                    dockWindow.localHyprDockState = {
                        busy: ws.windows > 0 || !!(special && special.windows > 0),
                        fullscreen: !!ws.hasfullscreen || !!(special && special.hasfullscreen)
                    };
                } catch (e) {}
            }
        }
    }

'''
try:
    source = path.read_text()
    if marker in source:
        start = source.index('    // Query the compositor directly:')
        end = source.index('    property alias swayPoller: swayPoller', start)
        updated = source[:start] + poll + source[end:]
        if updated == source:
            sys.exit(0)
        path.write_text(updated)
        sys.exit(10)
    busy = '    readonly property bool isWorkspaceBusy: {\n'
    anchor = '    property alias swayPoller: swayPoller\n'
    if source.count(busy) != 1 or source.count(anchor) != 1:
        raise ValueError('dock workspace detection changed; fix needs manual review')
    if old_fullscreen in source:
        source2 = source.replace(old_fullscreen, new_fullscreen, 1)
    elif previous_fix in source:
        source2 = source.replace(previous_fix, new_fullscreen, 1)
    else:
        raise ValueError('dock fullscreen detection changed; fix needs manual review')
    source2 = source2.replace(busy, busy + '        if (isHyprland && localHyprDockState !== null) return !!localHyprDockState.busy;\n', 1)
    updated = source2.replace(anchor, poll + anchor, 1)
    fd, temp = tempfile.mkstemp(prefix='.DockWindowState.', suffix='.qml', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(updated)
        os.chmod(temp, path.stat().st_mode & 0o777)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp): os.unlink(temp)
    sys.exit(10)
except (OSError, ValueError) as exc:
    print(f'Serpantinum dock: {exc}', file=sys.stderr)
    sys.exit(1)
