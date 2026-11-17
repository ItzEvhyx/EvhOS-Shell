#!/usr/bin/env python3
"""Generate bounded picker previews, prioritizing the latest visible selection."""
import argparse
from collections import deque
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
from urllib.parse import unquote, urlparse

from PIL import Image, ImageOps

SIZE = (1280, 720)
VERSION = "picker-cover-v1"


def source_path(source):
    parsed = urlparse(source)
    if parsed.scheme == "file" and parsed.netloc in ("", "localhost"):
        return Path(unquote(parsed.path))
    if not parsed.scheme and Path(source).is_absolute():
        return Path(source)
    raise ValueError("Only local preview sources are accepted")


def cache_path(source, directory):
    path = source_path(source)
    stat = path.stat()
    key = f"{VERSION}\0{path}\0{stat.st_mtime_ns}\0{stat.st_size}"
    return path, directory / (hashlib.sha256(key.encode()).hexdigest() + ".jpg")


def prepare(source, directory):
    path, cached = cache_path(source, directory)
    if cached.is_file() and cached.stat().st_size > 0:
        return cached
    directory.mkdir(parents=True, exist_ok=True)
    with Image.open(path) as original:
        original.seek(0)
        original.draft("RGB", SIZE)
        image = ImageOps.exif_transpose(original)
        # Crop rather than letterbox, matching the card and desktop cover behavior.
        image = ImageOps.fit(image.convert("RGB"), SIZE, Image.Resampling.LANCZOS)
        with tempfile.NamedTemporaryFile(dir=directory, suffix=".jpg", delete=False) as file:
            staged = Path(file.name)
        try:
            image.save(staged, "JPEG", quality=86)
            staged.replace(cached)
        finally:
            staged.unlink(missing_ok=True)
    return cached


class PreviewQueue:
    def __init__(self, directory):
        self.directory = directory
        self.condition = threading.Condition()
        self.output_lock = threading.Lock()
        self.pending = deque()
        self.inflight = set()
        self.emitted = set()
        self.closed = False

    def send(self, source, path):
        record = (source, path.as_uri())
        with self.output_lock:
            if record not in self.emitted:
                print(json.dumps({"source": source, "thumbnail": record[1]}), flush=True)
                self.emitted.add(record)

    def replace(self, sources):
        missing = []
        for source in dict.fromkeys(sources[:49]):
            if not isinstance(source, str):
                continue
            try:
                _, cached = cache_path(source, self.directory)
                if cached.is_file() and cached.stat().st_size:
                    self.send(source, cached)
                else:
                    missing.append(source)
            except (OSError, ValueError):
                continue
        with self.condition:
            self.pending = deque(s for s in missing if s not in self.inflight)
            self.condition.notify_all()

    def worker(self):
        while True:
            with self.condition:
                self.condition.wait_for(lambda: self.pending or self.closed)
                if not self.pending:
                    return
                source = self.pending.popleft()
                self.inflight.add(source)
            try:
                self.send(source, prepare(source, self.directory))
            except (OSError, ValueError, Image.DecompressionBombError):
                pass  # The UI retains its original-image fallback.
            finally:
                with self.condition:
                    self.inflight.discard(source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, required=True)
    args = parser.parse_args()
    queue = PreviewQueue(args.cache_dir.resolve())
    workers = [threading.Thread(target=queue.worker, daemon=True) for _ in range(2)]
    for worker in workers:
        worker.start()
    try:
        for line in sys.stdin:
            try:
                value = json.loads(line)
                if isinstance(value, list):
                    queue.replace(value)
            except (ValueError, TypeError):
                continue
    finally:
        with queue.condition:
            queue.closed = True
            queue.condition.notify_all()
        for worker in workers:
            worker.join()


if __name__ == "__main__":
    main()
