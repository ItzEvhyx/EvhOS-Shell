#!/usr/bin/env python3
"""Restore a reviewed EvhOS snapshot into a user's home; backups are mandatory."""
import argparse, datetime, os, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE_HOME = '/home/yhvhan'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--home', type=Path, default=Path.home(), help='target home (use a temporary directory for testing)')
    ap.add_argument('--apply', action='store_true', help='write files; without this flag only preview')
    args=ap.parse_args()
    home=args.home.expanduser().resolve()
    if os.geteuid()==0:
        ap.error('Run as the desktop user, not root.')
    if not (ROOT/'snapshot/shell/src/quickshell/Shell.qml').is_file():
        ap.error('Snapshot is incomplete; extract all repository files first.')
    backup=home/'.local/state/evhos-backups'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    mappings=[(ROOT/'snapshot/shell',home/'.local/share/serpantinum'),(ROOT/'snapshot/home',home)]
    items=[]
    for src,dest in mappings:
        for path in sorted(src.rglob('*')):
            if path.is_file() or path.is_symlink():
                target=dest/path.relative_to(src)
                if not target.parent.resolve().is_relative_to(home):
                    raise SystemExit('Target escapes home: '+str(target))
                items.append((path,target))
    print(('RESTORE' if args.apply else 'PREVIEW')+f': {len(items)} files into {home}')
    print('Existing files will be backed up to:',backup)
    if not args.apply: return
    if not home.exists(): home.mkdir(parents=True)
    for source,target in items:
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.is_symlink() or target.exists():
            saved=backup/target.relative_to(home);saved.parent.mkdir(parents=True,exist_ok=True)
            if target.is_symlink(): saved.symlink_to(os.readlink(target));target.unlink()
            elif target.is_file(): shutil.copy2(target,saved)
            else: raise SystemExit('Refusing to overwrite non-file: '+str(target))
        if source.is_symlink():
            target.symlink_to(os.readlink(source)); continue
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
