#!/usr/bin/env python3
"""Exercise Arch install flow without invoking package managers or modifying home."""
import os, pathlib, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='evhos-installer-') as td:
    base=pathlib.Path(td); binary=base/'bin';binary.mkdir();log=base/'calls'
    mocks={
      'pacman':'''#!/bin/sh
case "$1" in
  -T) [ "$2" = quickshell ] && exit 0; exit 1;;
  -Si) [ "$2" = "$EVHOS_MISSING" ] && exit 1; exit 0;;
  -Q) exit 1;;
esac
exit 1
''',
      'sudo':'''#!/bin/sh
printf 'sudo %s\\n' "$*" >> "$EVHOS_TEST_LOG"
[ "$1" = test ] && exit 1
[ "$1" = tee ] && cat >/dev/null
exit 0
''',
      'python3':'''#!/bin/sh
printf 'python %s\\n' "$*" >> "$EVHOS_TEST_LOG"
exit 0
''',
      'systemctl':'''#!/bin/sh
printf 'systemctl %s\\n' "$*" >> "$EVHOS_TEST_LOG"
exit 0
''',
      'fc-cache':'''#!/bin/sh
printf 'fc-cache\\n' >> "$EVHOS_TEST_LOG"
exit 0
''',
      'Hyprland':'#!/bin/sh\nexit 0\n', 'quickshell':'#!/bin/sh\nexit 0\n', 'sddm':'#!/bin/sh\nexit 0\n',
    }
    for name,content in mocks.items():
        p=binary/name;p.write_text(content);p.chmod(0o755)
    # Exercise Arch using a disposable installer copy, independent of host distro.
    release=base/'os-release';release.write_text('ID=arch\nID_LIKE=arch\n')
    installer=base/'install.sh'
    original=(root/'install.sh').read_text()
    assert '. /etc/os-release' in original
    installer.write_text(original.replace('. /etc/os-release', '. "'+str(release)+'"'))
    installer.chmod(0o755)
    (base/'restore.py').touch()
    shell=base/'snapshot/shell/src/quickshell/Shell.qml'
    shell.parent.mkdir(parents=True);shell.write_text('import QtQuick\nItem {}\n')
    env=os.environ.copy();env.update(PATH=str(binary)+os.pathsep+env['PATH'],EVHOS_TEST_LOG=str(log),EVHOS_MISSING='wl-gammarelay-rs')
    result=subprocess.run([str(installer),'--yes','--enable-services','--sddm'],env=env,text=True,capture_output=True)
    assert result.returncode==0, result.stdout+result.stderr
    assert 'wl-gammarelay-rs' in result.stdout
    calls=log.read_text();assert 'sudo pacman -S --needed' in calls
    assert ' quickshell ' not in calls, 'existing quickshell provider must not be replaced'
    assert 'restore.py --apply' in calls and 'systemctl --user enable --now' in calls
    assert 'sudo tee /etc/sddm.conf.d/zzzzzzz-evhos.conf' in calls
    log.unlink();env['EVHOS_MISSING']='qt6-svg'
    result=subprocess.run([str(installer),'--yes'],env=env,text=True,capture_output=True)
    assert result.returncode!=0 and 'qt6-svg' in result.stderr
    assert not log.exists(), 'missing core dependency must fail before changes'
print('Mocked installer checks passed; no packages or system settings changed.')
