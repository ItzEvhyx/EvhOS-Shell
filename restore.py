#!/usr/bin/env python3
"""Restore a reviewed EvhOS snapshot into a user's home; backups are mandatory."""
import argparse, datetime, json, os, shutil, subprocess, sys
from pathlib import Path
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent
SOURCE_HOME = json.loads((ROOT/'snapshot/metadata.json').read_text()).get('source_home', '/home/yhvhan') if (ROOT/'snapshot/metadata.json').exists() else '/home/yhvhan'
NOTES_PLUGIN = Path('src/quickshell/quickactions/actions/RichNotes')


def icon_member(member, destination):
    if not (member.isfile() or member.islnk()):
        raise ValueError('Unexpected icon archive entry: '+member.name)
    return tarfile.data_filter(member, destination)


def build_notes_plugin(directory):
    source = ROOT/'snapshot/shell'/NOTES_PLUGIN/'source/native'
    for command in ('cmake', 'ctest'):
        if not shutil.which(command):
            raise SystemExit(f'Missing {command}. See docs/INSTALL.md for rich notepad build dependencies.')
    subprocess.run(['cmake', '-S', str(source), '-B', str(directory), '-DCMAKE_BUILD_TYPE=Release'], check=True)
    subprocess.run(['cmake', '--build', str(directory), '--parallel', '2'], check=True)
    subprocess.run(['ctest', '--test-dir', str(directory), '--output-on-failure'], check=True)
    return directory/'RichNotes/libevhnotesplugin.so'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--home', type=Path, default=Path.home(), help='target home (use a temporary directory for testing)')
    ap.add_argument('--apply', action='store_true', help='write files; without this flag only preview')
    ap.add_argument('--build-rich-notes', action='store_true', help='compile and test the rich notepad Qt plugin before restoring')
    args=ap.parse_args()
    home=args.home.expanduser().resolve()
    if os.geteuid()==0:
        ap.error('Run as the desktop user, not root.')
    if not (ROOT/'snapshot/shell/src/quickshell/Shell.qml').is_file():
        ap.error('Snapshot is incomplete; extract all repository files first.')
    if (ROOT/'tools/check-snapshot.py').is_file():
        subprocess.run([sys.executable, str(ROOT/'tools/check-snapshot.py')], check=True)
    with tempfile.TemporaryDirectory(prefix='evhos-restore-') as directory:
        restore(home, Path(directory), args.apply, args.build_rich_notes)


def restore(home, staging, apply, build_rich_notes):
    backup=home/'.local/state/evhos-backups'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    icons = staging/'icons'
    for bundle in sorted((ROOT/'snapshot/icon-packs').glob('*.tar.gz')):
        with tarfile.open(bundle, 'r:gz') as archive:
            archive.extractall(icons, filter=icon_member)
    shell = home/'.local/share/serpantinum'
    mappings=[(ROOT/'snapshot/shell', shell), (ROOT/'snapshot/home', home), (icons, home/'.local/share/icons')]
    items=[]
    for src,dest in mappings:
        for path in sorted(src.rglob('*')):
            if path.is_file() or path.is_symlink():
                target=dest/path.relative_to(src)
                if not target.parent.resolve().is_relative_to(home):
                    raise SystemExit('Target escapes home: '+str(target))
                items.append((path,target))
    if build_rich_notes:
        plugin = shell/NOTES_PLUGIN/'libevhnotesplugin.so'
        if not plugin.parent.resolve().is_relative_to(home):
            raise SystemExit('Target escapes home: '+str(plugin))
        if apply:
            items.append((build_notes_plugin(staging/'notes-build'), plugin))
        else:
            print('A native rich notepad plugin will be built before restoring.')
    print(('RESTORE' if apply else 'PREVIEW')+f': {len(items)} files into {home}')
    print('Existing files will be backed up to:',backup)
    if not apply: return
    if not home.exists(): home.mkdir(parents=True)
    for source,target in items:
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.is_symlink() or target.exists():
            saved=backup/target.relative_to(home);saved.parent.mkdir(parents=True,exist_ok=True)
            if target.is_symlink(): saved.symlink_to(os.readlink(target));target.unlink()
            elif target.is_file(): shutil.copy2(target,saved)
            else: raise SystemExit('Refusing to overwrite non-file: '+str(target))
        if source.is_symlink():
            target.symlink_to(os.readlink(source).replace(SOURCE_HOME,str(home))); continue
        data=source.read_bytes()
        if b'\x00' not in data:
            try:
                data=data.decode('utf-8').replace(SOURCE_HOME,str(home)).encode('utf-8')
            except UnicodeDecodeError: pass
        target.write_bytes(data);shutil.copymode(source,target)
    bindir=home/'.local/bin';bindir.mkdir(parents=True,exist_ok=True)
    for name in ('serpantinum','serpantinumd'):
        link=bindir/name;wanted=Path('../share/serpantinum/bin')/name
        if link.is_symlink() or link.exists():
            saved=backup/link.relative_to(home);saved.parent.mkdir(parents=True,exist_ok=True)
            if link.is_symlink():saved.symlink_to(os.readlink(link));link.unlink()
            elif link.is_file():shutil.copy2(link,saved);link.unlink()
            else:raise SystemExit('Refusing to replace directory '+str(link))
        link.symlink_to(wanted)
    print('Restore complete. Restart the session only after reviewing README.md.')
    print('Backup:',backup)
if __name__=='__main__': main()
