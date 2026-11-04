#!/usr/bin/env python3
"""Put QuixiCore in the Steam library, with its artwork, so Game Mode has a tile.

Steam keeps non-Steam shortcuts in a binary VDF at
    <steam>/userdata/<account-id>/config/shortcuts.vdf
and the artwork for them in
    <steam>/userdata/<account-id>/config/grid/<appid>_p.png   (portrait capsule)
    <steam>/userdata/<account-id>/config/grid/<appid>_hero.png
    <steam>/userdata/<account-id>/config/grid/<appid>_logo.png
    <steam>/userdata/<account-id>/config/grid/<appid>.png     (wide capsule)

Doing it by hand means Add a Non-Steam Game, then right-click, then Properties, then four images.
This does all of it and writes nothing else.

Nothing here is clever about the format: the file is read, the new entry is appended to the existing
byte stream, and the result is parsed again to prove the old entries are still there. Steam must be
closed — it rewrites this file on exit and would drop the change — so the script refuses to write
while it is running.

    deck-steam-shortcut.py                 # say what it would do
    deck-steam-shortcut.py --write         # do it
    deck-steam-shortcut.py --write --art steam/   # ...and install the artwork
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path

APP_NAME = "QuixiCore"
APP_ID = "io.github.volkdude85.quixidesk"
EXE = "/usr/bin/flatpak"
LAUNCH_OPTIONS = f"run {APP_ID}"
START_DIR = "/usr/"


# --- the format ------------------------------------------------------------------------------

def read_str(data: bytes, pos: int) -> tuple[str, int]:
    end = data.index(b"\x00", pos)
    return data[pos:end].decode("utf-8", "replace"), end + 1


def parse_all(data: bytes) -> dict:
    """Parse the whole file with an absolute cursor (binary VDF nests only one level here)."""
    pos = 0

    def obj() -> dict:
        nonlocal pos
        out: dict = {}
        while pos < len(data):
            kind = data[pos]
            if kind == 0x08:
                pos += 1
                return out
            pos += 1
            key, pos_after = read_str(data, pos)
            pos = pos_after
            if kind == 0x00:
                out[key] = obj()
            elif kind == 0x01:
                out[key], pos = read_str(data, pos)
            elif kind == 0x02:
                out[key] = struct.unpack("<i", data[pos:pos + 4])[0]
                pos += 4
            elif kind == 0x07:
                out[key] = struct.unpack("<Q", data[pos:pos + 8])[0]
                pos += 8
            else:
                raise ValueError(f"unknown VDF type {kind:#x} for key {key!r} at byte {pos - 1}")
        return out

    root = obj()
    return root


def s(key: str, value: str) -> bytes:
    return b"\x01" + key.encode() + b"\x00" + value.encode() + b"\x00"


def i32(key: str, value: int) -> bytes:
    return b"\x02" + key.encode() + b"\x00" + struct.pack("<i", value)


def steam_appid(exe: str, name: str) -> tuple[int, int]:
    """Choose a stable shortcut id.

    Valve does not derive this from the exe and name: the two shortcuts Steam wrote on this machine
    carry ids that no crc32 of their fields reproduces, so they were assigned, not computed. The file
    is the source of truth — whatever number is stored here is the one Steam uses, and the artwork has
    to be named after it. So this is a deterministic choice of our own, with the high bit set the way
    Steam's own non-Steam ids are.
    """
    unsigned = (zlib.crc32((EXE + name).encode("utf-8")) & 0xFFFFFFFF) | 0x80000000
    signed = unsigned - (1 << 32) if unsigned >= (1 << 31) else unsigned
    return unsigned, signed


def entry_bytes(index: int, appid_signed: int) -> bytes:
    body = b""
    body += i32("appid", appid_signed)
    body += s("AppName", APP_NAME)
    body += s("Exe", f'"{EXE}"')
    body += s("StartDir", START_DIR)
    body += s("icon", "")
    body += s("ShortcutPath", "")
    body += s("LaunchOptions", LAUNCH_OPTIONS)
    body += i32("IsHidden", 0)
    body += i32("AllowDesktopConfig", 1)
    body += i32("AllowOverlay", 1)
    body += i32("OpenVR", 0)
    body += i32("Devkit", 0)
    body += s("DevkitGameID", "")
    body += i32("DevkitOverrideAppID", 0)
    body += i32("LastPlayTime", 0)
    body += s("FlatpakAppID", APP_ID)
    body += s("sortas", "")
    body += b"\x00tags\x00" + b"\x01" + b"0\x00" + APP_NAME.encode() + b"\x00" + b"\x08"
    return b"\x00" + str(index).encode() + b"\x00" + body + b"\x08"


def append_offset(data: bytes) -> int:
    """Byte offset just after the last child of the top-level 'shortcuts' object.

    The file ends in a run of object terminators — one per nested object plus the top-level one, and
    Steam leaves an extra. Counting them is guesswork that changes between Steam versions, so this
    walks the structure and returns where the last entry actually ends. The new entry goes there and
    every existing byte keeps its position.
    """
    if not data.startswith(b"\x00"):
        raise ValueError("shortcuts.vdf does not begin with an object")
    pos = 1
    _, pos = read_str(data, pos)          # "shortcuts"
    last_end = pos
    while pos < len(data):
        if data[pos] == 0x08:             # end of the shortcuts object
            break
        if data[pos] != 0x00:
            raise ValueError(f"expected an entry at byte {pos}, found {data[pos]:#x}")
        pos += 1
        _, pos = read_str(data, pos)      # entry index
        depth = 1
        while pos < len(data) and depth:
            kind = data[pos]
            if kind == 0x08:
                pos += 1
                depth -= 1
                continue
            pos += 1
            _, pos = read_str(data, pos)  # key
            if kind == 0x00:
                depth += 1
            elif kind == 0x01:
                _, pos = read_str(data, pos)
            elif kind == 0x02:
                pos += 4
            elif kind == 0x07:
                pos += 8
            else:
                raise ValueError(f"unknown VDF type {kind:#x} at byte {pos - 1}")
        last_end = pos
    return last_end


# --- locating things -------------------------------------------------------------------------

def find_userdata(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    roots = [Path.home() / ".local/share/Steam", Path.home() / ".steam/steam",
             Path.home() / ".steam/root"]
    for root in roots:
        userdata = root / "userdata"
        if not userdata.is_dir():
            continue
        # Pick the account that actually has a config directory with shortcuts in it.
        candidates = [d for d in sorted(userdata.iterdir()) if (d / "config").is_dir()]
        for d in candidates:
            if (d / "config/shortcuts.vdf").exists():
                return d
        if candidates:
            return candidates[0]
    raise SystemExit("Could not find Steam's userdata directory. Pass --userdata <path>.")


def steam_running() -> bool:
    for name in ("steam", "steamwebhelper"):
        r = subprocess.run(["pgrep", "-x", name], capture_output=True)
        if r.returncode == 0:
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true", help="actually modify shortcuts.vdf")
    ap.add_argument("--art", help="directory holding grid-460x215.png, grid-600x900.png, hero-1920x620.png, logo-1280x720.png")
    ap.add_argument("--userdata", help="Steam userdata/<id> directory (auto-detected otherwise)")
    ap.add_argument("--force", action="store_true", help="write even if Steam is running")
    args = ap.parse_args()

    userdata = find_userdata(args.userdata)
    vdf = userdata / "config/shortcuts.vdf"
    grid = userdata / "config/grid"
    unsigned_id, signed_id = steam_appid(f'"{EXE}"', APP_NAME)

    print(f"steam userdata : {userdata}")
    print(f"shortcuts      : {vdf}  ({'exists' if vdf.exists() else 'missing'})")
    print(f"appid          : {unsigned_id} (signed {signed_id})")

    data = vdf.read_bytes() if vdf.exists() else b""
    root = parse_all(data) if data else {}
    shortcuts = root.get("shortcuts", {})
    print(f"existing       : {len(shortcuts)} shortcut(s): {[v.get('AppName') for v in shortcuts.values()]}")

    already = any(str(v.get("FlatpakAppID", "")) == APP_ID or v.get("AppName") == APP_NAME
                  for v in shortcuts.values())
    if already:
        print("\nAlready in the library — nothing to add. Artwork is refreshed below if --art is given.")
    else:
        cut = append_offset(data)
        new = data[:cut] + entry_bytes(len(shortcuts), signed_id) + data[cut:]
        # Prove it before writing: parse the result and check the old entries survived.
        check = parse_all(new).get("shortcuts", {})
        if len(check) != len(shortcuts) + 1 or check.get(str(len(shortcuts)), {}).get("AppName") != APP_NAME:
            raise SystemExit("self-check failed: the appended entry did not parse back. Nothing written.")
        if [check[str(n)].get("AppName") for n in range(len(shortcuts))] != [v.get("AppName") for v in shortcuts.values()]:
            raise SystemExit("self-check failed: an existing shortcut changed. Nothing written.")
        print(f"would add      : {APP_NAME} (index {len(shortcuts)}), launch {LAUNCH_OPTIONS}")

        if not args.write:
            print("\nDry run. Re-run with --write to change the file.")
        else:
            if steam_running() and not args.force:
                raise SystemExit("Steam is running — it rewrites shortcuts.vdf on exit and would drop this. "
                                 "Close Steam and run again (or pass --force).")
            backup = vdf.with_suffix(f".vdf.bak-{time.strftime('%Y%m%d-%H%M%S')}")
            shutil.copy2(vdf, backup)
            tmp = vdf.with_suffix(".vdf.tmp")
            tmp.write_bytes(new)
            tmp.replace(vdf)
            print(f"wrote          : {vdf}  (backup {backup.name})")

    if args.art:
        art = Path(args.art)
        pairs = [("grid-600x900.png", f"{unsigned_id}_p.png"),
                 ("hero-1920x620.png", f"{unsigned_id}_hero.png"),
                 ("logo-1280x720.png", f"{unsigned_id}_logo.png"),
                 ("grid-460x215.png", f"{unsigned_id}.png")]
        missing = [src for src, _ in pairs if not (art / src).exists()]
        if missing:
            print(f"\nartwork        : not found in {art}: {', '.join(missing)}")
        else:
            if args.write:
                grid.mkdir(parents=True, exist_ok=True)
                for src, dst in pairs:
                    shutil.copy2(art / src, grid / dst)
                print(f"artwork        : {len(pairs)} images into {grid}")
            else:
                print(f"artwork        : would copy {len(pairs)} images into {grid}")

    if not args.write:
        print("\nNothing was changed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
