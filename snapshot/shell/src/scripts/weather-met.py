#!/usr/bin/env python3
"""MET Norway Locationforecast adapter for EvhOs/Serpantinum.

Forecast data: MET Norway, CC BY 4.0, https://api.met.no/doc/License
Converted to the existing shell schema; temperatures are model estimates.
"""
import argparse
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
import fcntl
import gzip
import json
import math
import os
from pathlib import Path
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

PROVIDER = "met-norway"
API = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
USER_AGENT = "EvhOs-Serpantinum-Weather/1.0 (personal desktop application)"
UTC = timezone.utc


def load(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(value, out, ensure_ascii=False, allow_nan=False)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def stamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def coordinates(loc):
    lat, lon = loc.get("latitude"), loc.get("longitude")
    if lat is None or lon is None:
        raise ValueError("No weather location configured")
    lat, lon = float(lat), float(lon)
    if not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError("Invalid weather coordinates")
    return lat, lon


def local_zone(loc):
    name = loc.get("timezone")
    if name and name != "auto":
        try:
            return ZoneInfo(name)
        except ZoneInfoNotFoundError:
            pass
    return datetime.now().astimezone().tzinfo or UTC


def date_header(value, default):
    try:
        return parsedate_to_datetime(value).timestamp()
    except (TypeError, ValueError, OverflowError):
        return default


def download(loc, cache, now=None, opener=urlopen):
    now = time.time() if now is None else now
    lat, lon = coordinates(loc)
    # Four-decimal truncation is required for efficient shared provider caches.
    query = urlencode({"lat": f"{math.trunc(lat * 10000) / 10000:.4f}",
                       "lon": f"{math.trunc(lon * 10000) / 10000:.4f}"})
    url = API + "?" + query
    old = load(cache)
    same = old.get("url") == url and bool(old.get("payload"))
    if old.get("url") == url and now < old.get("next_request_at", 0):
        if same and (not old.get("stale") or now - old.get("checked_at", 0) <= 21600):
            return old["payload"], old.get("stale", False), old.get("checked_at", 0)
        raise ValueError("Weather provider retry is pending")
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json", "Accept-Encoding": "gzip"}
    if same and old.get("last_modified"):
        headers["If-Modified-Since"] = old["last_modified"]
    try:
        try:
            with opener(Request(url, headers=headers), timeout=18) as response:
                body = response.read(4 * 1024 * 1024)
                if response.headers.get("Content-Encoding") == "gzip":
                    body = gzip.decompress(body)
                payload = json.loads(body)
                if not payload.get("properties", {}).get("timeseries"):
                    raise ValueError("Provider returned no forecast")
                expires = date_header(response.headers.get("Expires"), now + 900)
                meta = {"url": url, "payload": payload, "checked_at": now, "stale": False,
                        "last_modified": response.headers.get("Last-Modified", ""),
                        "next_request_at": max(expires, now + 60)}
                # Retain earlier points for today's high/low after later refreshes.
                if same:
                    cutoff = datetime.fromtimestamp(now, UTC) - timedelta(hours=30)
                    merged = {p["time"]: p for p in old["payload"]["properties"]["timeseries"]
                              if stamp(p["time"]) >= cutoff}
                    merged.update({p["time"]: p for p in payload["properties"]["timeseries"]})
                    payload["properties"]["timeseries"] = [merged[k] for k in sorted(merged)]
                write(cache, meta)
                return payload, False, now
        except HTTPError as exc:
            if exc.code == 304 and same:
                old.update(checked_at=now, stale=False,
                           next_request_at=max(date_header(exc.headers.get("Expires"), now + 900), now + 60))
                write(cache, old)
                exc.close()
                return old["payload"], False, now
            raise
    except (OSError, ValueError, HTTPError, URLError, TimeoutError) as exc:
        retry = now + 300
        if isinstance(exc, HTTPError) and exc.code in (403, 429):
            retry_value = exc.headers.get("Retry-After", "")
            retry = now + max(3600, int(retry_value)) if retry_value.isdigit() else max(now + 3600, date_header(retry_value, now + 3600))
        if isinstance(exc, HTTPError):
            exc.close()
        if not same:
            write(cache, {"url": url, "next_request_at": retry, "stale": True})
        if same:
            old.update(next_request_at=retry, stale=True)
            write(cache, old)
            if now - old.get("checked_at", 0) <= 21600:
                print("Weather: using cached MET Norway forecast: " + str(exc), file=sys.stderr)
                return old["payload"], True, old.get("checked_at", 0)
        raise


def symbol(data):
    for key in ("next_1_hours", "next_6_hours", "next_12_hours"):
        value = data.get(key, {}).get("summary", {}).get("symbol_code")
        if value:
            return value
    return "cloudy"


def mapped(code, i18n):
    base = code.split("_")[0]
    if "thunder" in base:
        condition, icon, color, key = "storm", "", "#f9e2af", "storm"
    elif "snow" in base or "sleet" in base:
        condition, icon, color, key = "snow", "", "#cdd6f4", "snow"
    elif "rain" in base:
        condition, icon, color, key = "rain", "󰖗", "#74c7ec", "rainy"
    elif base == "fog":
        condition, icon, color, key = "fog", "󰖑", "#84afdb", "mist"
    elif base == "clearsky":
        night = code.endswith("_night")
        condition, icon, color, key = ("moon", "", "#cba6f7", "clear") if night else ("sun", "", "#f9e2af", "sunny")
    elif base in ("fair", "partlycloudy"):
        return {"condition": "partly-cloudy-night" if code.endswith("_night") else "partly-cloudy",
                "icon": "", "hex": "#bac2de", "desc": "Partly cloudy"}
    else:
        condition, icon, color, key = "cloud", "", "#bac2de", "cloudy"
    defaults = {"storm": "Thunderstorms", "snow": "Snow", "rainy": "Rain", "mist": "Fog",
                "clear": "Clear", "sunny": "Sunny", "cloudy": "Cloudy"}
    return {"condition": condition, "icon": icon, "hex": color, "desc": i18n.get(key) or defaults[key]}


def temperature(c, unit):
    if not finite(c):
        return ""
    return f"{(c * 1.8 + 32 if unit == 'imperial' else c + 273.15 if unit == 'standard' else c):.1f}"


def normalize(payload, loc, unit, i18n=None, now=None, stale=False, checked_at=None):
    now = now or datetime.now(UTC)
    i18n = i18n or {}
    zone = local_zone(loc)
    local_now = now.astimezone(zone)
    rows = []
    for entry in payload["properties"]["timeseries"]:
        at = stamp(entry["time"])
        details = entry.get("data", {}).get("instant", {}).get("details", {})
        if not finite(details.get("air_temperature")):
            continue
        rows.append({"at": at, "local": at.astimezone(zone), "details": details,
                     "data": entry["data"], "map": mapped(symbol(entry["data"]), i18n)})
    rows.sort(key=lambda row: row["at"])
    if not rows:
        raise ValueError("Provider returned no usable temperatures")
    current = min(rows, key=lambda row: abs((row["at"] - now).total_seconds()))
    if abs((current["at"] - now).total_seconds()) > 7200:
        raise ValueError("Cached forecast no longer covers the current time")
    groups = defaultdict(list)
    for row in rows:
        groups[row["local"].date()].append(row)
    def slot(row, upcoming=False):
        value = row["map"]
        label = row["local"].strftime("%H:%M")
        if upcoming and row["local"].date() != local_now.date():
            label = row["local"].strftime("%a %H:%M")
        return dict(time=label, timestamp=int(row["at"].timestamp()),
                    temp=temperature(row["details"]["air_temperature"], unit),
                    **value)
    forecast = []
    for i in range(5):
        date = local_now.date() + timedelta(days=i)
        items = groups.get(date, [])
        if not items:
            continue
        temps = [r["details"]["air_temperature"] for r in items]
        for r in items:
            for key in ("next_1_hours", "next_6_hours"):
                # Only use extrema if the entire period stays within this local day.
                hours = 1 if key == "next_1_hours" else 6
                if (r["local"] + timedelta(hours=hours)).date() != date:
                    continue
                d = r["data"].get(key, {}).get("details", {})
                temps += [d[k] for k in ("air_temperature_min", "air_temperature_max") if finite(d.get(k))]
        representative = min(items, key=lambda r: abs(r["local"].hour - 12))
        winds = [r["details"].get("wind_speed") for r in items if finite(r["details"].get("wind_speed"))]
        humidity = [r["details"].get("relative_humidity") for r in items if finite(r["details"].get("relative_humidity"))]
        hours = [slot(r) for r in items if r["local"].hour % 3 == 0]
        if not hours:
            hours = [slot(r) for r in items]  # Global medium-range data uses six-hour steps.
        forecast.append(dict(id=str(i), iso_date=date.isoformat(), day=date.strftime("%a"),
                             day_full=date.strftime("%A"), date=date.strftime("%d %b"),
                             max=temperature(max(temps), unit), min=temperature(min(temps), unit),
                             wind=str(round(max(winds) * (2.236936 if unit == "imperial" else 3.6))) if winds else "",
                             humidity=str(round(sum(humidity) / len(humidity))) if humidity else "",
                             partial_day=items[0]["local"].hour > 0, hourly=hours,
                             **representative["map"]))
    if not forecast or forecast[0]["iso_date"] != local_now.date().isoformat():
        raise ValueError("No forecast for the current local day")
    sym = {"imperial": "°F", "standard": "K"}.get(unit, "°C")
    current_temp = temperature(current["details"]["air_temperature"], unit)
    lat, lon = coordinates(loc)
    upcoming = [slot(r, True) for r in rows if r["at"] >= now and r["local"].hour % 3 == 0][:4]
    return dict(provider=PROVIDER, provider_name="MET Norway", source_url="https://api.met.no/",
                license_url="https://creativecommons.org/licenses/by/4.0/", source_modified=True,
                latitude=lat, longitude=lon, city=loc.get("city", ""), timezone=str(zone),
                location_updated_at=loc.get("updated_at", 0), fetched_at=int(checked_at or now.timestamp()),
                model_updated_at=payload["properties"].get("meta", {}).get("updated_at", ""),
                valid_at=current["at"].isoformat(), generated_at=int(now.timestamp()),
                unit=unit, unit_sym=sym, stale=bool(stale), offline=False,
                current_temp=current_temp, current_temp_formatted=current_temp + sym,
                current_icon=current["map"]["icon"], current_hex=current["map"]["hex"],
                current_condition=current["map"]["condition"], current_desc=current["map"]["desc"],
                upcoming_hourly=upcoming, forecast=forecast)


def offline(loc, unit, error):
    sym = {"imperial": "°F", "standard": "K"}.get(unit, "°C")
    return dict(provider=PROVIDER, provider_name="MET Norway", source_url="https://api.met.no/",
                offline=True, stale=True, error=str(error), forecast=[], city=loc.get("city", ""),
                unit=unit, unit_sym=sym, current_temp="", current_temp_formatted="--" + sym,
                current_icon="", current_hex="#cdd6f4", fetched_at=0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--location", required=True)
    parser.add_argument("--unit", default="metric", choices=("metric", "imperial", "standard"))
    parser.add_argument("--cache-dir", required=True, type=Path)
    parser.add_argument("--i18n", default="{}")
    args = parser.parse_args()
    loc = json.loads(args.location)
    args.cache_dir.mkdir(parents=True, exist_ok=True)
    # One lock covers network and atomic publication across overlapping refreshes.
    with (args.cache_dir / "met-norway.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            payload, stale, checked = download(loc, args.cache_dir / "met-norway-raw.json")
            result = normalize(payload, loc, args.unit, json.loads(args.i18n), stale=stale, checked_at=checked)
        except (OSError, ValueError, KeyError, TypeError, URLError, TimeoutError) as exc:
            print("Weather unavailable: " + str(exc), file=sys.stderr)
            result = offline(loc, args.unit, exc)
        write(args.cache_dir / "weather.json", result)
    return 0 if not result["offline"] else 1


if __name__ == "__main__":
    sys.exit(main())
