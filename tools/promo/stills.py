#!/usr/bin/env python3
"""Takes the README screenshots the promo video does not have (the ⚙ menu, one per tab) on the promo stage: the same
throw-away launcher and demo configuration record.py uses, with tools/promo/stills.body as the script. It writes
full-screen PNGs to the output folder; crop them to 1366x686 like the others (see docs/development.md).

It takes over the screen for about 15 seconds, so do not type or click while it runs.
Usage: tools/promo/stills.py [output folder]   (default: tools/promo/out/stills)"""
import os, shutil, subprocess, sys, tempfile, threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage

out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "stills"))
os.makedirs(out, exist_ok=True)
body = open(os.path.join(HERE, "stills.body")).read()
work = tempfile.mkdtemp(prefix="gona-stills-")
try:
    plug, home = stage.build(body, work)
    # the runner's no-op hyprctl first on PATH: the Super key setup must not reload the real Hyprland
    env = dict(os.environ, HOME=home, GONA_STILLS=out, GONA_SCREEN=stage.focused_monitor(), PATH=os.path.join(work, "bin") + os.pathsep + os.environ["PATH"])
    qs = subprocess.Popen(["quickshell", "-n", "-p", os.path.join(plug, "shell.qml")], env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    threading.Timer(90, qs.kill).start()
    for line in qs.stdout:
        if "ERROR" in line and "portal" not in line: print(line.rstrip())
        if "UI-DONE" in line: break
    qs.terminate()
    try: qs.wait(5)
    except subprocess.TimeoutExpired: qs.kill()
    print("\n".join(sorted(os.path.join(out, f) for f in os.listdir(out))))
finally:
    shutil.rmtree(work, ignore_errors=True)
