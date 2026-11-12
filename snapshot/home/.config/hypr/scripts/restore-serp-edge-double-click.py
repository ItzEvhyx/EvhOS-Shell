#!/usr/bin/env python3
"""Serpantinum: double-click to reveal panels; always visible on empty workspaces.

Run with Python 3 (no sudo). --check validates without changing live files.
--home PATH is available for checking an isolated copy of the configuration.
"""
import argparse
from datetime import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

MARKER = '// local double-click reveal v1'
HELPER = 'restore-serp-edge-double-click.py'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one matching section, found {text.count(old)}: {old[:85]}')
    return text.replace(old, new, 1)


def patch_bar(text):
    if MARKER in text:
        return text
    text = replace_once(text, 'import Quickshell.Io\n', 'import Quickshell.Io\nimport Quickshell.Hyprland\n')
    anchor = '            property bool autohide: {\n'
    state = '''            // local double-click reveal v1
            readonly property bool localUsesHyprland: Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            property bool localWorkspaceBusy: true
            property string localWorkspaceKey: ""
            property bool localEdgeRevealed: false

            function localResetReveal() {
                localEdgeRevealed = false;
                hideTimer.stop();
            }
            onLocalWorkspaceBusyChanged: localResetReveal()
            onLocalWorkspaceKeyChanged: localResetReveal()
            onAutohideChanged: localResetReveal()

            Timer {
                id: localWorkspaceRefresh
                interval: 20
                onTriggered: {
                    if (localWorkspacePoller.running) restart();
                    else localWorkspacePoller.running = true;
                }
            }
            Connections {
                target: barWindowRoot.localUsesHyprland ? Hyprland : null
                function onRawEvent(event) {
                    if (!event || !event.name) return;
                    if (["workspace", "workspacev2", "focusedmon", "focusedmonv2", "activespecial", "activespecialv2"].includes(event.name))
                        barWindowRoot.localResetReveal();
                    if (["workspace", "workspacev2", "focusedmon", "focusedmonv2", "openwindow", "closewindow", "movewindow", "movewindowv2", "activespecial", "activespecialv2", "fullscreen"].includes(event.name))
                        localWorkspaceRefresh.restart();
                }
            }
            Timer {
                interval: 750
                repeat: true
                running: barWindowRoot.localUsesHyprland
                triggeredOnStart: true
                onTriggered: if (!localWorkspacePoller.running) localWorkspacePoller.running = true
            }
            Process {
                id: localWorkspacePoller
                command: ["bash", "-c", "{ hyprctl -j monitors && hyprctl -j workspaces; } | jq -s ."]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let data = JSON.parse(this.text);
                            let mon = data[0].find(m => barWindowRoot.screen && m.name === barWindowRoot.screen.name);
                            if (!mon) return;
                            let ws = data[1].find(w => w.id === mon.activeWorkspace.id);
                            let special = mon.specialWorkspace && mon.specialWorkspace.id
                                ? data[1].find(w => w.id === mon.specialWorkspace.id) : null;
                            if (!ws) return;
                            barWindowRoot.localWorkspaceKey = String(ws.id) + ":" + (special ? special.id : 0);
                            barWindowRoot.localWorkspaceBusy = ws.windows > 0 || !!(special && special.windows > 0);
                        } catch (e) {}
                    }
                }
            }

'''
    text = replace_once(text, anchor, state + anchor + '                if (localUsesHyprland) return localWorkspaceBusy;\n')
    text = replace_once(text, '                interval: barWindowRoot.autohideTimeout\n', '                interval: barWindowRoot.autohideTimeout\n                onTriggered: barWindowRoot.localEdgeRevealed = false\n')
    text = replace_once(text, '                if (!barHover.hovered && barWindowRoot.autohide) {', '                if (localEdgeRevealed && !barHover.hovered && barWindowRoot.autohide && !localPanelOpen) {')
    old = '''                if (barHover.hovered) return true;
                if (hideTimer.running) return true;'''
    text = replace_once(text, old, '                if (localPanelOpen) return true;\n                if (localEdgeRevealed) return true;')
    anchor = '            property bool isRevealed: {\n'
    controls = '''            readonly property bool localPanelOpen: isNotifOpen || isSysOpen || (TrayMenuController.isVisible && TrayMenuController.screen === barWindowRoot.screen)
            onLocalPanelOpenChanged: checkHideTimer()

            // Only the hidden panel's thin input strip catches the double-click.
            // Visible controls keep their normal click behavior.
            MouseArea {
                anchors.fill: parent
                z: 100000
                enabled: barWindowRoot.autohide && !barWindowRoot.isRevealed && !barWindowRoot.shouldHideForRedact
                acceptedButtons: Qt.LeftButton
                onDoubleClicked: function(mouse) {
                    barWindowRoot.localEdgeRevealed = true;
                    hideTimer.stop();
                    barWindowRoot.checkHideTimer();
                    mouse.accepted = true;
                }
            }

'''
    return replace_once(text, anchor, controls + anchor)


def patch_dock(text):
    if MARKER in text:
        return text
    text = replace_once(text, 'import Quickshell.Wayland\n', 'import Quickshell.Wayland\nimport Quickshell.Hyprland\n')
    text = replace_once(text, '    onEffectiveAutohideChanged: hideTimer.stop()', '''    // local double-click reveal v1
    property bool localEdgeRevealed: false
    function localResetReveal() {
        localEdgeRevealed = false;
        hideTimer.stop();
    }
    onEffectiveAutohideChanged: localResetReveal()
    onIsWorkspaceBusyChanged: localResetReveal()
    onIsFullscreenActiveChanged: localResetReveal()
    Connections {
        target: dockWindowRoot.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event && ["workspace", "workspacev2", "focusedmon", "focusedmonv2", "activespecial", "activespecialv2"].includes(event.name))
                dockWindowRoot.localResetReveal();
        }
    }''')
    text = replace_once(text, '    onActiveIndexChanged: {\n        hideTimer.stop();', '    onActiveIndexChanged: {\n        localResetReveal();')
    text = replace_once(text, '    property real autohideHitSize: s(18)', '    property real autohideHitSize: s(4) // thin double-click strip')
    text = replace_once(text, '        interval: dockWindowRoot.autohideTimeout\n', '        interval: dockWindowRoot.autohideTimeout\n        onTriggered: dockWindowRoot.localEdgeRevealed = false\n')
    text = replace_once(text, '        if (!dockHover.hovered && !edgeHover.hovered && dockWindowRoot.effectiveAutohide && !dockWindowRoot.editMode && !isMenuOpen) {', '        if (localEdgeRevealed && !dockHover.hovered && !edgeHover.hovered && dockWindowRoot.effectiveAutohide && !dockWindowRoot.editMode && !isMenuOpen) {')
    text = replace_once(text, '        if (!effectiveAutohide) return true;', '        if (!isWorkspaceBusy || !effectiveAutohide) return true;')
    text = replace_once(text, '''        if (dockHover.hovered) return true;
        if (edgeHover.hovered) return true;
        if (hideTimer.running) return true;''', '        if (localEdgeRevealed) return true;')
    # Keep the edge and dock hover handlers solely for keeping an already opened
    # dock visible. Neither can open it or start the grace timer when hidden.
    anchor = '''        HoverHandler {
            id: edgeHover'''
    controls = '''        MouseArea {
            anchors.fill: parent
            enabled: !dockWindowRoot.isRevealed
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: function(mouse) {
                dockWindowRoot.localEdgeRevealed = true;
                hideTimer.stop();
                dockWindowRoot.checkHideTimer();
                mouse.accepted = true;
            }
        }

'''
    return replace_once(text, anchor, controls + anchor)


def atomic_write(path, content, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--repair', action='store_true', help='Reapply after shell upgrades; exits 10 if changed')
    parser.add_argument('--home', type=Path, default=Path.home())
    args = parser.parse_args()
    home = args.home.resolve()
    shell = home / '.local/share/serpantinum/src'
    scripts = home / '.config/hypr/scripts'
    pending = []
    for relative, transform in [('bar/Bar.qml', patch_bar), ('dock/DockWindow.qml', patch_dock)]:
        path = shell / 'quickshell' / relative
        original = path.read_text()
        updated = transform(original)
        # Parse every proposed QML file before any live writes.
        with tempfile.TemporaryDirectory(prefix='serp-edge-') as directory:
            probe = Path(directory) / path.name
            parse_source = updated
            if relative == 'bar/Bar.qml':
                # The installed qmlformat rejects the shell's existing typed
                # IPC declarations. They are untouched by this patch; exclude
                # only that identical block from the syntax-only probe.
                start = '            IpcHandler {\n'
                end = '            required property var modelData\n'
                old_ipc = original[original.index(start):original.index(end, original.index(start))]
                new_ipc = updated[updated.index(start):updated.index(end, updated.index(start))]
                if old_ipc != new_ipc:
                    raise ValueError('Unexpected IPC declaration change')
                parse_source = replace_once(updated, new_ipc, '')
            probe.write_text(parse_source)
            check = subprocess.run(['qmlformat', str(probe)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            if check.returncode:
                raise ValueError(f'{path.name} failed QML parsing: {check.stderr}')
        if updated != original:
            pending.append((path, updated))
    if not args.repair:
        hook = scripts / 'restore-serp-customizations.sh'
        original = hook.read_text()
        entry = '"$HOME/.config/hypr/scripts/' + HELPER + '"'
        if entry not in original:
            pending.append((hook, replace_once(original, '; do\n', ' ' + entry + '; do\n')))
        installed = scripts / HELPER
        own_source = Path(__file__).read_text()
        if not installed.exists() or installed.read_text() != own_source:
            pending.append((installed, own_source))
    if args.check:
        print(f'QML parsing passed. {len(pending)} files would be updated; no live files changed.')
        return 0
    if not pending:
        if not args.repair:
            print('Already installed.')
        return 0
    backup = home / '.local/state/serpantinum-edge-backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, exist_ok=False)
    originals = []
    try:
        for path, content in pending:
            mode = path.stat().st_mode & 0o777 if path.exists() else 0o755
            old = path.read_text() if path.exists() else None
            if old is not None:
                target = backup / path.relative_to(home)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
            originals.append((path, old, mode))
            atomic_write(path, content, mode)
    except Exception:
        for path, old, mode in reversed(originals):
            if old is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, old, mode)
        raise
    if args.repair:
        return 10
    print(f'Installed. Original files backed up in {backup}')
    if home == Path.home().resolve():
        reload_result = subprocess.run(['bash', str(shell / 'scripts/reload.sh')])
        if reload_result.returncode:
            print('Files installed; shell reload failed. Log out and back in to activate.', file=sys.stderr)
            return 1
        print('Shell reloaded. Double-click the screen edge to reveal; empty workspaces stay visible.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f'No installation completed: {error}', file=sys.stderr)
        sys.exit(1)
