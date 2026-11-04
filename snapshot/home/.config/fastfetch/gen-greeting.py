import json, os

home = os.path.expanduser("~")
cfg_path = os.path.join(home, ".config/fastfetch/greeting.jsonc")
colors_path = os.path.join(home, ".local/state/serpantinum/qs_colors.json")
scheme_path = os.path.join(home, ".local/state/caelestia/scheme.json")

DOT_KEYS = ["red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink"]

def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

primary = header = dots = None

# Serpantinum palette (preferred)
try:
    c = json.load(open(colors_path))
    primary = c.get("blue") or c.get("mauve")
    header = c.get("mauve") or primary
    picked = [c[k] for k in DOT_KEYS if k in c]
    if picked:
        dots = "".join("\u001b[38;2;%d;%d;%dm\u25cf " % rgb(h) for h in picked) + "\u001b[0m"
except Exception:
    pass

# Caelestia fallback (labels and headers only)
if not primary:
    try:
        c = json.load(open(scheme_path))["colours"]
        primary = "#" + c["primary"].lstrip("#")
        header = "#" + c.get("secondary", c["primary"]).lstrip("#")
    except Exception:
        raise SystemExit  # keep current colors

cfg = json.load(open(cfg_path))
for i, m in enumerate(cfg["modules"]):
    if not isinstance(m, dict):
        continue
    t = m.get("type")
    if t == "colors" and dots:
        cfg["modules"][i] = {"type": "custom", "format": dots}
    elif t == "custom" and "\u25cf" in m.get("format", ""):
        if dots:
            m["format"] = dots
    elif t == "custom":
        m["outputColor"] = header
    elif "keyColor" in m:
        m["keyColor"] = primary
json.dump(cfg, open(cfg_path, "w"), indent=2, ensure_ascii=False)
