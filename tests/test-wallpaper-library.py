#!/usr/bin/env python3
"""Exercise the real scanner/watcher and poster invalidation in temporary folders."""
import fcntl
import importlib.util
import json
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

SCRIPT = Path(__file__).resolve().parents[1]/'snapshot/shell/src/scripts/wallpaper/indexer.py'
spec = importlib.util.spec_from_file_location('wallpaper_indexer', SCRIPT)
indexer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(indexer)


class WallpaperLibraryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/'Wallpapers'
        (self.root/'Pictures').mkdir(parents=True)
        (self.root/'Videos').mkdir()
        self.cache = Path(self.temp.name)/'cache'
        self.run = Path(self.temp.name)/'run'

    def index(self):
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.root), str(self.cache), str(self.run)], check=True, capture_output=True, text=True, timeout=30)
        return json.loads(result.stdout)

    def test_move_keeps_colors_and_updates_path(self):
        old = self.root/'test image.png'
        Image.new('RGB', (16, 16), 'blue').save(old)
        first = self.index()['items'][0]
        moved = self.root/'Pictures'/old.name
        old.rename(moved)
        second = self.index()['items'][0]
        self.assertEqual(second['filePath'], str(moved))
        self.assertEqual(first['hex'], second['hex'])
        self.assertIn('/Pictures/', second['fileUrl'])

    def test_watcher_add_rename_and_remove(self):
        process = subprocess.Popen([sys.executable, str(SCRIPT), '--watch', str(self.root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        def event():
            self.assertTrue(selector.select(5), 'No metadata change event')
            result = json.loads(process.stdout.readline())
            self.assertEqual(result['signature'], indexer.library_signature(str(self.root)))
            return result['signature']
        try:
            signatures = [event()]
            Image.new('RGB', (8, 8), 'red').save(self.root/'Pictures/new.JPG')
            signatures.append(event())
            video = self.root/'Videos/clip.Mp4'
            video.write_bytes(b'metadata watcher does not decode media')
            signatures.append(event())
            renamed = video.with_name('renamed.Mp4')
            video.rename(renamed)
            signatures.append(event())
            renamed.unlink()
            signatures.append(event())
            self.assertTrue(all(a != b for a, b in zip(signatures, signatures[1:])))
            self.assertEqual(signatures[-1], signatures[1])
        finally:
            process.terminate()
            process.wait(timeout=5)
            process.stdout.close()
            process.stderr.close()
            selector.close()

    def test_locked_index_requests_a_followup(self):
        self.index()
        lock = self.run/('indexer_'+indexer.get_dir_hash(str(self.root))+'.lock')
        with lock.open('w') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            self.assertTrue(self.index()['indexingPending'])

    @unittest.skipUnless(shutil.which('ffmpeg'), 'ffmpeg is required for video posters')
    def test_updated_video_regenerates_poster(self):
        video = self.root/'Videos/clip.mp4'
        def movie(color):
            subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c='+color+':s=160x90:d=1', '-an', '-c:v', 'libx264', str(video)], check=True, timeout=15)
        movie('red')
        first = self.index()['items'][0]
        movie('blue')
        second = self.index()['items'][0]
        self.assertNotEqual(first['posterUrl'], second['posterUrl'])
        with Image.open(second['posterPath']) as image:
            r, g, b = image.convert('RGB').getpixel((30, 30))
        self.assertGreater(b, r+100)


if __name__ == '__main__':
    unittest.main()
