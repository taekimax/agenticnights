#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
staged_app="$project_root/.build/agenticnights.app"
installed_app="/Applications/agenticnights.app"
codesign --verify --deep --strict "$staged_app"
python3 - "$staged_app" "$installed_app" <<'PY'
import datetime
import os
import pathlib
import plistlib
import shutil
import signal
import subprocess
import sys
import time

stage, destination = map(pathlib.Path, sys.argv[1:])
expected_id = "com.tk.agenticnights"
with (stage / "Contents/Info.plist").open("rb") as stream:
    assert plistlib.load(stream)["CFBundleIdentifier"] == expected_id

if destination.exists():
    with (destination / "Contents/Info.plist").open("rb") as stream:
        if plistlib.load(stream).get("CFBundleIdentifier") != expected_id:
            raise SystemExit("Destination belongs to another app; it has been preserved.")
    executable = str(destination / "Contents/MacOS/agenticnights")
    rows = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True).splitlines()
    pids = [int(row.strip().split(None, 1)[0]) for row in rows
            if len(row.strip().split(None, 1)) == 2
            and row.strip().split(None, 1)[1] == executable]
    for pid in pids:
        os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 10
    while pids and time.monotonic() < deadline:
        remaining = []
        for pid in pids:
            try:
                os.kill(pid, 0)
                remaining.append(pid)
            except ProcessLookupError:
                pass
        pids = remaining
        if pids:
            time.sleep(0.1)
    if pids:
        raise SystemExit("App did not finish quitting; previous installation preserved.")
    # Only workers whose executable is inside this exact app bundle belong here.
    rows = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True).splitlines()
    workers = [int(row.strip().split(None, 1)[0]) for row in rows
               if len(row.strip().split(None, 1)) == 2
               and row.strip().split(None, 1)[1].startswith(str(destination / "Contents/Frameworks/Sparkle.framework") + "/")]
    for pid in workers:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 5
    while workers and time.monotonic() < deadline:
        alive = []
        for pid in workers:
            try:
                os.kill(pid, 0)
                alive.append(pid)
            except ProcessLookupError:
                pass
        workers = alive
        if workers:
            time.sleep(0.1)
    if workers:
        raise SystemExit("Sparkle workers did not quit; previous installation preserved.")
    trash = pathlib.Path.home() / ".Trash"
    trash.mkdir(exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    recovery = trash / f"agenticnights-{stamp}.app"
    # A signed bundle's root remains owner-writable; never chmod recursively.
    if destination.stat().st_uid == os.getuid():
        destination.chmod(destination.stat().st_mode | 0o200)
    destination.rename(recovery)
    print(f"Previous app retained: {recovery}")
shutil.copytree(stage, destination, symlinks=True)
destination.chmod(destination.stat().st_mode | 0o200)
print(f"Installed: {destination}")
PY
codesign --verify --deep --strict --verbose=2 "$installed_app"
cmp "$staged_app/Contents/MacOS/agenticnights" "$installed_app/Contents/MacOS/agenticnights"
python3 - "$staged_app" "$installed_app" <<'PY'
import hashlib
import os
import pathlib
import stat
import sys

def inventory(root):
    entries = {}
    for folder, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            path = pathlib.Path(folder) / name
            relative = str(path.relative_to(root))
            mode = stat.S_IMODE(path.lstat().st_mode)
            if path.is_symlink():
                entries[relative] = ('symlink', os.readlink(path))
            elif path.is_file():
                entries[relative] = ('file', mode, hashlib.sha256(path.read_bytes()).hexdigest())
            else:
                entries[relative] = ('directory', mode)
    return entries

assert inventory(pathlib.Path(sys.argv[1])) == inventory(pathlib.Path(sys.argv[2])), 'Installed payload differs from stage'
PY
print 'PASS: installed signature and full staged/installed payload equality'
