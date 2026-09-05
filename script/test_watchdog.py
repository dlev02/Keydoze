#!/usr/bin/env python3
"""Independent, test-only process termination. Never shipped inside the app."""
import argparse
import os
import signal
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("pid", type=int, nargs="?")
parser.add_argument("--activate", action="store_true")
parser.add_argument("--seconds", type=float, default=20)
args = parser.parse_args()
expected = str(Path(__file__).resolve().parent.parent / "dist/Keydoze.app/Contents/MacOS/Keydoze")
def matches(pid):
    check = subprocess.run(["ps", "-p", str(pid), "-o", "command="], capture_output=True, text=True)
    return check.returncode == 0 and check.stdout.strip().startswith(expected + " ")
if args.pid is None:
    result = subprocess.run(["pgrep", "-x", "Keydoze"], capture_output=True, text=True)
    matches_here = [int(pid) for pid in result.stdout.split() if matches(int(pid))]
    if len(matches_here) != 1:
        raise SystemExit("Refusing: expected exactly one project-local test app.")
    args.pid = matches_here[0]
def still_target():
    return matches(args.pid)
if not still_target():
    raise SystemExit("Refusing: PID is not this project's test app.")
seconds = min(30, max(5, args.seconds))
print(f"ARMED: independently terminate Keydoze PID {args.pid} in {seconds:g}s", flush=True)
end = time.monotonic() + seconds
if args.activate:
    subprocess.run(["open", str(Path(expected).parents[2])], check=True)
while time.monotonic() < end:
    if not still_target():
        print("App exited before watchdog deadline.", flush=True)
        raise SystemExit(0)
    time.sleep(0.1)
if still_target():
    os.kill(args.pid, signal.SIGKILL)
    print("Watchdog terminated the test app.", flush=True)
