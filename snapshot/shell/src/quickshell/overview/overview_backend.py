#!/usr/bin/env python3
"""Take a temporary pre-overlay frame and switch Hyprland workspaces."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def dispatch(modern, legacy, runner=subprocess.run):
    for command in (modern, legacy):
        result = runner(["hyprctl", "dispatch", command], capture_output=True, text=True, timeout=3)
        if result.returncode == 0 and not any(word in result.stdout.lower() for word in ("invalid", "not found", "error", "unknown")):
            return
    raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Could not switch workspace")


def switch_workspace(workspace, runner=subprocess.run):
    if workspace <= 0:
        raise ValueError("A numbered workspace is required")
    try:
        result = runner(["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=2)
        for monitor in json.loads(result.stdout):
            special = monitor.get("specialWorkspace", {})
            if monitor.get("focused") and special.get("id", 0) < 0:
                name = str(special.get("name", "special")).removeprefix("special:")
                dispatch("hl.dsp.workspace.toggle_special("+json.dumps(name)+")", "togglespecialworkspace "+name, runner)
    except (json.JSONDecodeError, TypeError):
        pass
    dispatch(f"hl.dsp.focus({{ workspace = {workspace} }})", f"workspace {workspace}", runner)


def capture(monitor, output, runner=subprocess.run):
    output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, name = tempfile.mkstemp(dir=output.parent, suffix=".png")
    os.close(descriptor)
    staged = Path(name)
    try:
        result = runner(["grim", "-o", monitor, "-l", "1", str(staged)], capture_output=True, timeout=2)
        if result.returncode == 0 and staged.stat().st_size:
            staged.chmod(0o600)
            staged.replace(output)
            return str(output)
    except (OSError, subprocess.TimeoutExpired):
        pass
    finally:
        staged.unlink(missing_ok=True)
    return ""


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=("capture","switch","cleanup"))
    parser.add_argument("--monitor",default="")
    parser.add_argument("--output",type=Path)
    parser.add_argument("--workspace",type=int)
    args=parser.parse_args()
    if args.action=="switch":
        if args.workspace is None: raise ValueError("No workspace selected")
        switch_workspace(args.workspace)
    elif args.action=="capture":
        if args.output is None: raise ValueError("No output path")
        print(json.dumps({"path":capture(args.monitor,args.output)}))
    elif args.output:
        args.output.unlink(missing_ok=True)


if __name__=="__main__":
    try: main()
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as error:
        print(str(error),file=sys.stderr);sys.exit(1)
