#!/usr/bin/env python3
"""Local filename/project search and desktop-editor launching for Serpantinum."""
import argparse
from collections import deque
import configparser
import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time

VERSION = 1
SKIP = {"node_modules", "vendor", "target", "build", "dist", "__pycache__", "venv", "env", "site-packages", "bower_components", "coverage", "Pods", "DerivedData"}
MARKERS = {".git", "package.json", "pnpm-workspace.yaml", "pyproject.toml", "requirements.txt", "Pipfile", "Cargo.toml", "go.mod", "pubspec.yaml", "composer.json", "pom.xml", "build.gradle", "build.gradle.kts", "CMakeLists.txt", "Makefile", "deno.json", "deno.jsonc", "project.godot"}
PROJECT_SUFFIXES = (".sln", ".csproj", ".fsproj", ".xcodeproj", ".code-workspace")
SOURCE_SUFFIXES = {".py", ".js", ".ts", ".tsx", ".jsx", ".rs", ".go", ".java", ".kt", ".dart", ".cpp", ".c", ".html", ".qml"}


def project_names(names):
    if MARKERS.intersection(names) or any(n.endswith(PROJECT_SUFFIXES) for n in names):
        return True
    return sum(Path(n).suffix.lower() in SOURCE_SUFFIXES for n in names) >= 2


def is_project(path):
    try:
        with os.scandir(path) as entries:
            return project_names({e.name for e in entries})
    except OSError:
        return False


def walk_home(home, depth=8, limit=200000):
    queue = deque([(home, 0)])
    count = 0
    priority = {n: i for i, n in enumerate(("Projects", "Documents", "Desktop", "Downloads", "Pictures"))}
    while queue and count < limit:
        root, level = queue.popleft()
        try:
            with os.scandir(root) as stream:
                entries = list(stream)
        except OSError:
            continue
        names = {e.name for e in entries}
        if root != home:
            yield (str(root), root.name, root.name.casefold(), 1, int(project_names(names)))
            count += 1
        children = []
        for entry in entries:
            if entry.name.startswith(".") or entry.name in SKIP:
                continue
            try:
                directory = entry.is_dir()
                if directory:
                    if level < depth and not entry.is_symlink():
                        children.append(Path(entry.path))
                    else:
                        yield (entry.path, entry.name, entry.name.casefold(), 1, int(is_project(entry.path)))
                        count += 1
                elif entry.is_file():
                    yield (entry.path, entry.name, entry.name.casefold(), 0, 0)
                    count += 1
            except OSError:
                continue
            if count >= limit:
                break
        for child in sorted(children, key=lambda p: (priority.get(p.name, 99), p.name.casefold())):
            queue.append((child, level + 1))


def index_home(home, cache, force=False):
    cache.mkdir(parents=True, exist_ok=True)
    database = cache / "project-files.sqlite3"
    if not force and database.exists() and time.time() - database.stat().st_mtime < 60:
        return
    with (cache / "project-files.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        descriptor, name = tempfile.mkstemp(dir=cache, suffix=".sqlite3")
        os.close(descriptor)
        staged = Path(name)
        try:
            with sqlite3.connect(staged) as connection:
                connection.execute("CREATE TABLE paths(path TEXT PRIMARY KEY,name TEXT, folded TEXT,is_dir INTEGER,is_project INTEGER)")
                connection.executemany("INSERT OR REPLACE INTO paths VALUES(?,?,?,?,?)", walk_home(home))
                connection.execute("CREATE INDEX names ON paths(folded)")
                connection.execute("CREATE TABLE metadata(version INTEGER,home TEXT)")
                connection.execute("INSERT INTO metadata VALUES(?,?)", (VERSION, str(home)))
            staged.replace(database)
        finally:
            staged.unlink(missing_ok=True)


def row_item(row, query):
    path, name, folded, directory, project = row
    q = query.casefold()
    if q == folded:
        score = 1200000 if project else 1100000
    elif folded.startswith(q):
        score = 85000 if project else 65000
    elif q in folded:
        score = 25000 if project else 18000
    else:
        score = 5000
    return dict(path=path, name=name, isDir=bool(directory), isProject=bool(project), score=score)


def search(home, cache, query, mode="all", limit=40):
    query = query.strip()
    if query.startswith(("/", "~")):
        requested = Path(os.path.expanduser(query))
        parent = requested if query.endswith("/") and requested.is_dir() else requested.parent
        prefix = "" if parent == requested else requested.name.casefold()
        try:
            results = []
            for item in parent.iterdir():
                if item.name.startswith(".") and not prefix.startswith("."):
                    continue
                if prefix and prefix not in item.name.casefold():
                    continue
                directory = item.is_dir()
                results.append(row_item((str(item), item.name, item.name.casefold(), directory, directory and is_project(item)), prefix))
            return sorted(results, key=lambda i: (-i["score"], not i["isDir"], i["name"].casefold()))[:limit]
        except OSError:
            return []
    if not query:
        return search(home, cache, str(home) + "/", mode, limit) if mode == "files" else []
    if len(query) < 2:
        return []
    found = {}
    database = cache / "project-files.sqlite3"
    if database.exists():
        try:
            with sqlite3.connect(f"{database.as_uri()}?mode=ro", uri=True) as connection:
                metadata = connection.execute("SELECT version,home FROM metadata").fetchone()
                if metadata != (VERSION, str(home)):
                    raise ValueError("Index belongs to a different root/version")
                pattern = "%" + query.casefold().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
                rows = connection.execute("SELECT * FROM paths WHERE folded LIKE ? ESCAPE '\\' ORDER BY (folded=?) DESC,is_project DESC,length(name),path LIMIT 200", (pattern, query.casefold())).fetchall()
                for row in rows:
                    if Path(row[0]).exists():
                        found[row[0]] = row_item(row, query)
        except (sqlite3.Error, ValueError):
            pass
    # Fresh top-level projects and downloads remain searchable between full scans.
    roots = [home] + [home / n for n in ("Projects", "Documents", "Desktop", "Downloads", "Pictures", "Videos", "Music")]
    for root in roots:
        try:
            for item in root.iterdir():
                if item.name.startswith(".") or query.casefold() not in item.name.casefold():
                    continue
                directory = item.is_dir()
                row = (str(item), item.name, item.name.casefold(), directory, directory and is_project(item))
                found[str(item)] = row_item(row, query)
        except OSError:
            continue
    return sorted(found.values(), key=lambda item: (-item["score"], item["name"].casefold(), item["path"]))[:limit]


def desktop_directories():
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    roots = [data_home] + [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    roots += [Path.home()/".local/share/flatpak/exports/share", Path("/var/lib/flatpak/exports/share")]
    return [p / "applications" for p in roots]


def discover_editors(directories=None):
    result = []
    seen_ids, seen_names = set(), set()
    for directory in directories or desktop_directories():
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.desktop")):
            if path.name in seen_ids:
                continue
            seen_ids.add(path.name)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(path, encoding="utf-8")
                entry = parser["Desktop Entry"]
                name = entry.get("Name", "")
                if entry.get("Hidden", "false").lower() == "true" or entry.get("NoDisplay", "false").lower() == "true":
                    continue
                categories = set(entry.get("Categories", "").split(";"))
                if not categories.intersection({"IDE", "TextEditor"}):
                    continue
                folder_editors = ("cursor", "code", "codium", "zed", "sublime", "atom", "kate", "kdevelop", "vim", "emacs", "geany", "lite-xl")
                if "IDE" not in categories and not any(part in (name + " " + path.name).casefold() for part in folder_editors):
                    continue
                if "url-handler" in path.name.lower() or "urlhandler" in path.name.lower():
                    continue
                tokens = shlex.split(entry.get("Exec", ""))
                if not tokens or not (shutil.which(tokens[0]) or (Path(tokens[0]).is_file() and os.access(tokens[0], os.X_OK))):
                    continue
                if entry.get("TryExec") and not shutil.which(entry["TryExec"]):
                    continue
                if name.casefold() in seen_names:
                    continue
                seen_names.add(name.casefold())
                result.append(dict(id=str(path.resolve()), name=name, icon=entry.get("Icon", ""), exec=entry["Exec"], terminal=entry.get("Terminal", "false").lower() == "true"))
            except (OSError, ValueError, KeyError, configparser.Error):
                continue
    order = {"cursor": 0, "visual studio code": 1, "antigravity": 2, "antigravity ide": 3, "zed": 4}
    return sorted(result, key=lambda e: (order.get(e["name"].casefold(), 10), e["name"].casefold()))


def editor_argv(editor, project):
    tokens = shlex.split(editor["exec"])
    argv = []
    placed = False
    for token in tokens:
        if token in ("%f", "%F", "%u", "%U"):
            argv.append(str(project) if token in ("%f", "%F") else project.as_uri())
            placed = True
        elif token == "%i":
            if editor["icon"]:
                argv.extend(["--icon", editor["icon"]])
        elif token == "%c":
            argv.append(editor["name"])
        elif token == "%k":
            argv.append(editor["id"])
        elif token in ("%d", "%D", "%n", "%N", "%v", "%m"):
            continue
        elif "%" in token:
            literal = token.replace("%%", "\0")
            if "%" in literal:
                raise ValueError("Unsupported desktop field code")
            argv.append(literal.replace("\0", "%"))
        else:
            argv.append(token)
    if not placed:
        argv.append(str(project))
    if editor["terminal"]:
        terminal = next((shutil.which(n) for n in ("foot", "kitty", "alacritty", "xterm") if shutil.which(n)), None)
        if not terminal:
            raise ValueError("A terminal is required for this editor")
        argv = [terminal, "-e"] + argv
    return argv


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("index", "search", "editors", "open", "file"))
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--cache-dir", type=Path, default=Path.home()/".cache/serpantinum/launcher")
    parser.add_argument("--query", default="")
    parser.add_argument("--mode", choices=("all", "files"), default="all")
    parser.add_argument("--request", type=int, default=0)
    parser.add_argument("--path", type=Path)
    parser.add_argument("--editor")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    home, cache = args.home.resolve(), args.cache_dir.resolve()
    if args.action == "index":
        index_home(home, cache, args.force)
    elif args.action == "search":
        print(json.dumps(dict(query=args.query.strip(), request=args.request, items=search(home, cache, args.query, args.mode, 40 if args.mode == "files" else 12))))
    elif args.action == "editors":
        print(json.dumps(discover_editors()))
    else:
        if args.path is None or not args.path.exists():
            raise ValueError("The selected path no longer exists")
        project = args.path.resolve()
        if args.action == "open":
            if not project.is_dir():
                raise ValueError("Select a project directory")
            editor = next((e for e in discover_editors() if e["id"] == args.editor), None)
            if editor is None:
                raise ValueError("The selected editor is no longer available")
            argv = editor_argv(editor, project)
        else:
            argv = ["xdg-open", str(project)]
        if args.dry_run:
            print(json.dumps(argv))
        else:
            subprocess.Popen(argv, cwd=str(project if project.is_dir() else project.parent), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, sqlite3.Error) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
