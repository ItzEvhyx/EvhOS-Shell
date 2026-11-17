#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1]/'snapshot/shell/src/quickshell/launcher/project_search.py'
spec = importlib.util.spec_from_file_location('project_search', SCRIPT)
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class ProjectLauncherTest(unittest.TestCase):
    def test_project_and_image_search(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)/'home'
            project = home/'Projects/wizyemm-website'
            project.mkdir(parents=True)
            (project/'package.json').write_text('{}')
            image = home/'Pictures/JhimPic_ID.jpeg'
            image.parent.mkdir()
            image.write_bytes(b'filename search fixture')
            ignored = project/'node_modules'
            ignored.mkdir()
            (ignored/'unwanted.txt').write_text('')
            cache = Path(folder)/'cache'
            backend.index_home(home, cache, force=True)
            projects = backend.search(home, cache, 'wizyemm-website')
            self.assertTrue(any(item['path'] == str(project) and item['isProject'] for item in projects))
            images = backend.search(home, cache, 'JhimPic_ID.jpeg')
            self.assertTrue(any(item['path'] == str(image) and not item['isDir'] for item in images))
            self.assertFalse(backend.search(home, cache, 'unwanted.txt'))

    def test_editor_arguments_keep_project_path_as_one_argument(self):
        project = Path('/tmp/project with spaces;literal')
        editor = {'exec': 'cursor --new-window %F', 'icon': 'cursor', 'name': 'Cursor', 'id': 'cursor.desktop', 'terminal': False}
        self.assertEqual(backend.editor_argv(editor, project), ['cursor', '--new-window', str(project)])


if __name__ == '__main__':
    unittest.main()
