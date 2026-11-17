import os
import sys
import json
import time
import hashlib
import fcntl
import subprocess
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

MEDIA_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".mp4", ".mkv", ".mov", ".webm"}


def library_signature(src_dir):
    entries = []
    for folder in [os.path.join(src_dir, "Pictures"), os.path.join(src_dir, "Videos"), src_dir]:
        try:
            with os.scandir(folder) as files:
                for entry in files:
                    try:
                        if not entry.is_file() or os.path.splitext(entry.name)[1].lower() not in MEDIA_EXTENSIONS:
                            continue
                        stat = entry.stat()
                        entries.append((entry.path, stat.st_size, stat.st_mtime_ns))
                    except OSError:
                        continue
        except OSError:
            continue
    return hashlib.sha256(json.dumps(sorted(entries)).encode()).hexdigest()


def watch_library(src_dir, interval=0.5, settle=0.5):
    """Watch metadata only; emit after writes settle, without decoding media."""
    observed = emitted = None
    changed_at = 0.0
    while True:
        signature = library_signature(src_dir)
        now = time.monotonic()
        if signature != observed:
            observed, changed_at = signature, now
        if signature != emitted and now - changed_at >= settle:
            print(json.dumps({"srcDir": os.path.abspath(src_dir), "signature": signature}), flush=True)
            emitted = signature
        time.sleep(interval)

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

def get_dir_hash(path):
    return hashlib.sha256(os.path.abspath(path).encode("utf-8")).hexdigest()[:16]

def get_color_bucket(hex_str):
    if not hex_str:
        return "Monochrome"
    hex_str = str(hex_str).strip().replace("#", "")
    if len(hex_str) > 6:
        hex_str = hex_str[:6]
    if len(hex_str) != 6:
        return "Monochrome"
    try:
        r = int(hex_str[0:2], 16) / 255.0
        g = int(hex_str[2:4], 16) / 255.0
        b = int(hex_str[4:6], 16) / 255.0
    except ValueError:
        return "Monochrome"

    mx = max(r, g, b)
    mn = min(r, g, b)
    d = mx - mn
    h = 0.0
    s = 0.0 if mx == 0 else d / mx
    v = mx

    if mx != mn:
        if mx == r:
            h = (g - b) / d + (6.0 if g < b else 0.0)
        elif mx == g:
            h = (b - r) / d + 2.0
        else:
            h = (r - g) / d + 4.0
        h /= 6.0
    h *= 360.0

    if s < 0.05 or v < 0.08:
        return "Monochrome"
    if h >= 345 or h < 15:
        return "Red"
    if 15 <= h < 45:
        return "Orange"
    if 45 <= h < 75:
        return "Yellow"
    if 75 <= h < 165:
        return "Green"
    if 165 <= h < 260:
        return "Blue"
    if 260 <= h < 315:
        return "Purple"
    if 315 <= h < 345:
        return "Pink"
    return "Monochrome"

def extract_color(filepath):
    if HAS_PIL:
        try:
            with Image.open(filepath) as im:
                im = im.convert("RGB").resize((1, 1), Image.Resampling.BOX)
                r, g, b = im.getpixel((0, 0))
                return f"#{r:02x}{g:02x}{b:02x}"
        except Exception:
            pass
    for cmd in ["magick", "convert"]:
        try:
            out = subprocess.check_output(
                [cmd, f"{filepath}[0]", "-resize", "1x1!", "-format", "%[hex:p{0,0}]", "info:-"],
                stderr=subprocess.DEVNULL,
                timeout=5
            ).decode("utf-8").strip()
            if len(out) >= 6:
                return f"#{out[:6]}"
        except Exception:
            continue
    return "#808080"

def generate_video_poster(video_path, poster_path, force=False):
    if not force and os.path.exists(poster_path) and os.path.getsize(poster_path) > 1024:
        return True
    os.makedirs(os.path.dirname(poster_path), exist_ok=True)
    tmp_poster = f"{poster_path}.tmp.jpg"
    for seek in ["00:00:01", "00:00:00.5", "00:00:02", None]:
        cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
        if seek:
            cmd += ["-ss", seek]
        cmd += [
            "-i", video_path,
            "-vframes", "1",
            "-vf", "scale=960:-2:force_original_aspect_ratio=decrease",
            "-q:v", "2",
            tmp_poster
        ]
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=8)
            if os.path.exists(tmp_poster) and os.path.getsize(tmp_poster) > 512:
                os.replace(tmp_poster, poster_path)
                return True
        except Exception:
            pass
    try:
        if os.path.exists(tmp_poster):
            os.remove(tmp_poster)
    except OSError:
        pass
    for cmd in ["magick", "convert"]:
        try:
            subprocess.run([cmd, "-size", "960x540", "xc:#1e1e2e", poster_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=5)
            return True
        except Exception:
            continue
    return False

def process_entry(entry_tuple, poster_dir, cached_items):
    fname, fpath, mtime, size, is_video = entry_tuple
    version = f"?v={mtime}-{size}"
    furl = "file://" + urllib.parse.quote(fpath) + ("" if is_video else version)

    existing = cached_items.get(fname)
    if existing and existing.get("mtime") == mtime and existing.get("size") == size:
        # A folder move does not change the file's timestamp or size.
        existing = dict(existing, filePath=fpath, fileUrl=furl)
        if is_video:
            p_path = existing.get("posterPath", "")
            if p_path and os.path.exists(p_path) and os.path.getsize(p_path) > 512:
                return existing
        else:
            return existing

    if is_video:
        poster_name = f"{hashlib.sha256(fname.encode('utf-8')).hexdigest()[:16]}.jpg"
        poster_path = os.path.join(poster_dir, poster_name)
        generate_video_poster(fpath, poster_path, force=existing is not None)
        poster_url = "file://" + urllib.parse.quote(poster_path) + version
        hex_color = extract_color(poster_path) if os.path.exists(poster_path) else "#808080"
        return {
            "fileName": fname,
            "filePath": fpath,
            "fileUrl": furl,
            "isVideo": True,
            "posterPath": poster_path,
            "posterUrl": poster_url,
            "hex": hex_color,
            "bucket": "Video",
            "mtime": mtime,
            "size": size
        }
    else:
        hex_color = extract_color(fpath)
        bucket = get_color_bucket(hex_color)
        return {
            "fileName": fname,
            "filePath": fpath,
            "fileUrl": furl,
            "isVideo": False,
            "posterPath": "",
            "posterUrl": "",
            "hex": hex_color,
            "bucket": bucket,
            "mtime": mtime,
            "size": size
        }

def run_indexing(src_dir, per_dir_cache, index_file, poster_dir):
    os.makedirs(per_dir_cache, exist_ok=True)
    os.makedirs(poster_dir, exist_ok=True)

    cached_items = {}
    if os.path.exists(index_file):
        try:
            with open(index_file, "r") as f:
                old_data = json.load(f)
                for item in old_data.get("items", []):
                    if item.get("fileName"):
                        cached_items[item.get("fileName")] = item
        except Exception:
            cached_items = {}

    img_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
    vid_exts = {".mp4", ".mkv", ".mov", ".webm"}

    entries_to_process = []
    seen_entry_names = set()
    seen_entry_paths = set()
    # Prefer the new split layout, while retaining loose-file compatibility.
    dir_entries = []
    for folder in [os.path.join(src_dir, "Pictures"), os.path.join(src_dir, "Videos"), src_dir]:
        try:
            with os.scandir(folder) as entries:
                dir_entries.extend(entries)
        except OSError:
            continue

    for entry in dir_entries:
        try:
            if not entry.is_file():
                continue
        except OSError:
            continue

        fname = entry.name
        if fname in seen_entry_names:
            continue

        ext = os.path.splitext(fname)[1].lower()
        if ext not in img_exts and ext not in vid_exts:
            continue

        try:
            real_path = os.path.realpath(entry.path)
            if real_path in seen_entry_paths:
                continue
            st = entry.stat()
            mtime = st.st_mtime
            size = int(st.st_size)
        except Exception:
            continue

        seen_entry_names.add(fname)
        seen_entry_paths.add(real_path)
        fpath = os.path.abspath(entry.path)
        is_video = ext in vid_exts
        entries_to_process.append((fname, fpath, mtime, size, is_video))

    workers = min(12, max(4, os.cpu_count() or 4))
    items_map = {}
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(process_entry, item, poster_dir, cached_items) for item in entries_to_process]
        for f in futures:
            try:
                res = f.result()
                if res and res.get("fileName") and res.get("filePath"):
                    fn = res["fileName"]
                    if fn not in items_map:
                        items_map[fn] = res
            except Exception:
                pass

    items = [items_map[k] for k in sorted(items_map.keys())]

    output_data = {
        "layoutVersion": 2,
        "srcDir": os.path.abspath(src_dir),
        "dirHash": get_dir_hash(src_dir),
        "updatedAt": int(time.time()),
        "items": items
    }

    tmp_index = f"{index_file}.tmp"
    with open(tmp_index, "w") as f:
        json.dump(output_data, f, indent=2)
    os.replace(tmp_index, index_file)

    current_symlink = os.path.join(os.path.dirname(os.path.dirname(per_dir_cache)), "current_index.json")
    tmp_symlink = f"{current_symlink}.tmp"
    with open(tmp_symlink, "w") as f:
        json.dump(output_data, f)
    os.replace(tmp_symlink, current_symlink)

    return output_data

def main():
    if len(sys.argv) < 2:
        return
    if sys.argv[1] == "--watch":
        if len(sys.argv) < 3:
            raise SystemExit("--watch requires a wallpaper library directory")
        directory = sys.argv[2]
        if directory.startswith("file://"):
            directory = urllib.parse.unquote(directory[7:])
        watch_library(directory)
        return
    src_dir = sys.argv[1]
    if src_dir.startswith("file://"):
        src_dir = urllib.parse.unquote(src_dir[7:])
    cache_dir = sys.argv[2] if len(sys.argv) > 2 else "/tmp"
    run_dir = sys.argv[3] if len(sys.argv) > 3 else cache_dir

    os.makedirs(cache_dir, exist_ok=True)
    os.makedirs(run_dir, exist_ok=True)

    dir_hash = get_dir_hash(src_dir)
    per_dir_cache = os.path.join(cache_dir, "dirs", dir_hash)
    poster_dir = os.path.join(per_dir_cache, "posters")
    index_file = os.path.join(per_dir_cache, "index.json")

    dirty_file = os.path.join(run_dir, f"indexer_{dir_hash}.dirty")
    lock_file = os.path.join(run_dir, f"indexer_{dir_hash}.lock")

    with open(lock_file, "w") as lock_fd:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError):
            with open(dirty_file, "w") as df:
                df.write("1")
            if os.path.exists(index_file):
                try:
                    with open(index_file, "r") as f:
                        pending_data = json.load(f)
                    pending_data["indexingPending"] = True
                    sys.stdout.write(json.dumps(pending_data))
                    sys.stdout.flush()
                except Exception:
                    pass
            else:
                sys.stdout.write(json.dumps({"srcDir": os.path.abspath(src_dir), "layoutVersion": 2, "items": [], "indexingPending": True}))
                sys.stdout.flush()
            sys.exit(0)

        result_data = None
        while True:
            if os.path.exists(dirty_file):
                try:
                    os.remove(dirty_file)
                except OSError:
                    pass
            result_data = run_indexing(src_dir, per_dir_cache, index_file, poster_dir)
            if not os.path.exists(dirty_file):
                break

        if result_data:
            sys.stdout.write(json.dumps(result_data))
            sys.stdout.flush()

if __name__ == "__main__":
    main()
