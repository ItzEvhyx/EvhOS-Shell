#!/usr/bin/env python3
"""Read-only, on-demand system telemetry for the Serpantinum Process Desk."""
import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return default


def number(path, divisor=1):
    try:
        return float(read(path)) / divisor
    except ValueError:
        return None


def cpu_ticks(text):
    rows = [line.split() for line in text.splitlines() if line.startswith("cpu ")]
    if not rows:
        return None
    vals = [int(v) for v in rows[0][1:9]]
    return sum(vals), vals[3] + (vals[4] if len(vals) > 4 else 0)


def utilization(previous, current):
    if not previous or not current or current[0] <= previous[0]:
        return None
    return max(0.0, min(100.0, 100 * (1 - (current[1]-previous[1])/(current[0]-previous[0]))))


def meminfo(text):
    values = {}
    for line in text.splitlines():
        parts = line.replace(":", " ").split()
        if len(parts) > 1 and parts[1].isdigit():
            values[parts[0]] = int(parts[1]) * 1024
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", values.get("MemFree", 0) + values.get("Buffers", 0) + values.get("Cached", 0))
    used = max(0, total - available)
    return dict(ram_used=used, ram_total=total, ram_percent=used/total*100 if total else None,
                swap_used=max(0, values.get("SwapTotal", 0)-values.get("SwapFree", 0)),
                swap_total=values.get("SwapTotal", 0))


def process_stat(text, page_size):
    end = text.rfind(")")
    if end < 0:
        raise ValueError("Incomplete process stat")
    name = text[text.find("(")+1:end]
    fields = text[end+2:].split()
    return name, int(fields[11])+int(fields[12]), int(fields[19]), max(0,int(fields[21])) * page_size


class Sampler:
    def __init__(self, proc=Path("/proc"), sys=Path("/sys"), disk_path=None):
        self.proc, self.sys = Path(proc), Path(sys)
        self.disk_path = Path(disk_path or Path.home())
        self.previous_cpu = None
        self.previous_procs = {}
        self.previous_net = {}
        self.previous_time = None
        self.slow_at = -1e9
        self.slow = {}
        self.gpu_discover_at = -1e9
        self.gpu_files = []
        self.previous_gpu = {}
        self.gpu_previous_at = None
        self.page_size = os.sysconf("SC_PAGE_SIZE")

    def slow_stats(self, now):
        if now - self.slow_at < 15:
            return self.slow
        result = dict(cpu_temp=None, gpu_temp=None, fan_rpm=None, gpu_frequency=None, gpu_name="GPU")
        cpu_candidates = []
        for hw in (self.sys / "class/hwmon").glob("hwmon*"):
            name = read(hw / "name")
            for temp in hw.glob("temp*_input"):
                value = number(temp, 1000)
                if value is None or not -20 < value < 150:
                    continue
                label = read(temp.with_name(temp.name.replace("_input", "_label"))).lower()
                if name in ("coretemp", "k10temp", "zenpower", "cpu_thermal"):
                    cpu_candidates.append((0 if any(s in label for s in ("package", "tctl", "tdie")) else 1, value))
                elif name in ("amdgpu", "nouveau", "nvidia"):
                    result["gpu_temp"] = value
            fans = [number(f) for f in hw.glob("fan*_input")]
            fans = [v for v in fans if v is not None and v >= 0]
            if fans:
                result["fan_rpm"] = max(fans)
        if cpu_candidates:
            priority = min(p for p, _ in cpu_candidates)
            result["cpu_temp"] = max(v for p, v in cpu_candidates if p == priority)
        else:
            for zone in (self.sys / "class/thermal").glob("thermal_zone*"):
                if read(zone / "type") in ("x86_pkg_temp", "cpu_thermal", "cpu-thermal"):
                    result["cpu_temp"] = number(zone / "temp", 1000)
                    break
        self.gpu_busy_paths = []
        for card in (self.sys / "class/drm").glob("card[0-9]*"):
            if "-" in card.name:
                continue
            vendor = read(card / "device/vendor")
            result["gpu_name"] = {"0x8086":"Intel GPU", "0x1002":"AMD GPU", "0x10de":"NVIDIA GPU"}.get(vendor,"GPU")
            busy = card / "device/gpu_busy_percent"
            if busy.exists():
                self.gpu_busy_paths.append(busy)
            for frequency in [card / "gt/gt0/rps_act_freq_mhz", card / "gt_cur_freq_mhz"]:
                if frequency.exists():
                    result["gpu_frequency"] = number(frequency)
                    break
        try:
            total, used, free = shutil.disk_usage(self.disk_path)
            result.update(disk_used=used, disk_total=total, disk_percent=used/total*100 if total else None)
        except OSError:
            result.update(disk_used=None, disk_total=None, disk_percent=None)
        self.slow_at, self.slow = now, result
        return result

    def gpu_usage(self, now, pid_dirs):
        # Prefer a direct driver sensor, otherwise use unique DRM-client engine counters.
        values = [number(path) for path in getattr(self,"gpu_busy_paths",[])]
        values = [v for v in values if v is not None]
        if values:
            return max(0,min(100,max(values)))
        if now - self.gpu_discover_at >= 15:
            found = []
            for directory in pid_dirs:
                try:
                    for fd in (directory / "fd").iterdir():
                        try:
                            target = os.readlink(fd)
                        except OSError:
                            continue
                        if target.startswith("/dev/dri/"):
                            found.append(directory / "fdinfo" / fd.name)
                except OSError:
                    continue
            self.gpu_files, self.gpu_discover_at = found, now
        clients = {}
        for path in self.gpu_files:
            info = read(path)
            fields = dict(line.split(":",1) for line in info.splitlines() if ":" in line)
            client = fields.get("drm-client-id")
            if not client:
                continue
            key = (fields.get("drm-pdev",""),client.strip())
            engines = {}
            for name,value in fields.items():
                if name.startswith("drm-engine-") and not name.startswith("drm-engine-capacity-"):
                    parts = value.split()
                    if len(parts) >= 2 and parts[0].isdigit() and parts[1] == "ns":
                        engines[name] = int(parts[0])
            clients[key] = engines
        deltas = defaultdict(int)
        for client, engines in clients.items():
            old = self.previous_gpu.get(client)
            if old:
                for engine,value in engines.items():
                    if engine in old:
                        deltas[engine] += max(0,value-old[engine])
        dt = now-self.gpu_previous_at if self.gpu_previous_at is not None else 0
        self.previous_gpu, self.gpu_previous_at = clients, now
        return min(100,max(deltas.values())/dt/1e9*100) if deltas and dt > 0 else None

    def sample(self, now=None):
        now = time.monotonic() if now is None else now
        ticks = cpu_ticks(read(self.proc / "stat"))
        result = dict(self.slow_stats(now))
        result.update(meminfo(read(self.proc / "meminfo")))
        result.update(cpu_percent=utilization(self.previous_cpu,ticks), uptime=None)
        # uptime contains two numbers; only the first is the running time.
        try:
            result["uptime"] = float(read(self.proc/"uptime").split()[0])
        except (ValueError,IndexError):
            result["uptime"] = None
        delta_total = ticks[0]-self.previous_cpu[0] if ticks and self.previous_cpu else 0
        groups, processes = {}, {}
        dirs = [p for p in self.proc.iterdir() if p.name.isdigit()]
        for directory in dirs:
            try:
                name, used, start, rss = process_stat(read(directory/"stat"),self.page_size)
            except (ValueError,IndexError):
                continue
            key = (directory.name,start)
            previous = self.previous_procs.get(key)
            cpu = max(0, used-previous)/delta_total*100 if previous is not None and delta_total > 0 else None
            processes[key] = used
            if name not in groups:
                groups[name] = dict(name=name,cpu=None,memory=0,count=0)
            group = groups[name]
            if cpu is not None:
                group["cpu"] = (group["cpu"] or 0) + cpu
            group["memory"] += rss
            group["count"] += 1
        result["gpu_percent"] = self.gpu_usage(now,dirs)
        result["processes"] = sorted(groups.values(), key=lambda p:(-(p["cpu"] or 0),-p["memory"]))
        net = {}
        for line in read(self.proc/"net/dev").splitlines()[2:]:
            if ":" not in line:
                continue
            name, data = line.split(":",1)
            name, parts = name.strip(),data.split()
            # Physical Ethernet/Wi-Fi only: avoid VPN/bridge double counting.
            if name != "lo" and len(parts) >= 9 and (self.sys/"class/net"/name/"device").exists():
                net[name] = (int(parts[0]),int(parts[8]))
        dt = now-self.previous_time if self.previous_time is not None else 0
        rates = [0.0,0.0]
        for name, counts in net.items():
            old = self.previous_net.get(name)
            if old and dt > 0:
                for i in range(2):
                    rates[i] += max(0,counts[i]-old[i])/dt
        result.update(net_rx=rates[0] if dt > 0 else None, net_tx=rates[1] if dt > 0 else None)
        self.previous_cpu,self.previous_procs = ticks,processes
        self.previous_net,self.previous_time = net,now
        return result


def open_monitor():
    if shutil.which("foot"):
        monitor = shutil.which("btop") or shutil.which("htop") or shutil.which("top")
        if monitor:
            subprocess.Popen(["foot","--title=System monitor","-e",monitor],start_new_session=True)
            return
    for app in ("gnome-system-monitor","plasma-systemmonitor"):
        if shutil.which(app):
            subprocess.Popen([app],start_new_session=True)
            return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once",action="store_true")
    parser.add_argument("--open-monitor",action="store_true")
    parser.add_argument("--interval",type=float,default=2)
    args = parser.parse_args()
    if args.open_monitor:
        open_monitor()
        return
    sampler = Sampler()
    if args.once:
        sampler.sample()
        time.sleep(0.2)
        print(json.dumps(sampler.sample(),allow_nan=False))
        return
    first = True
    try:
        while True:
            start = time.monotonic()
            print(json.dumps(sampler.sample(),allow_nan=False),flush=True)
            time.sleep(max(0.1,(0.4 if first else max(1,args.interval))-(time.monotonic()-start)))
            first = False
    except (BrokenPipeError,KeyboardInterrupt):
        pass


if __name__ == "__main__":
    main()
