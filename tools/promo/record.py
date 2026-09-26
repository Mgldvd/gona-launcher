#!/usr/bin/env python3
"""Records the promo video: runs tools/promo/director.body in a throw-away launcher (the same instance the UI tests use, with
its own HOME and a curated configuration) while gpu-screen-recorder captures the screen, then leaves the raw capture and
the times of the start and end marks in the output folder. tools/promo/edit.sh turns that into the final files.

It takes over the whole screen for about a minute: transparent full-screen windows, a backdrop and the launcher's own
keyboard focus, so do not type or click while it runs.
Usage: tools/promo/record.py [output folder]   (default: tools/promo/out)"""
import json, os, shutil, signal, subprocess, sys, tempfile, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage  # the throw-away launcher with the promo backdrop and the demo configuration

out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out"))
os.makedirs(out, exist_ok=True)
raw = os.path.join(out, "raw.mp4")
if os.path.exists(raw): os.remove(raw)

body = open(os.path.join(HERE, "director.body")).read()
work = tempfile.mkdtemp(prefix="gona-promo-")
try:
    plug, home = stage.build(body, work)

    monitor = stage.focused_monitor()
    rec = subprocess.Popen(["gpu-screen-recorder", "-w", monitor, "-f", "60", "-cursor", "no", "-q", "very_high", "-c", "mp4", "-o", raw],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    time.sleep(2.0)  # the recorder needs a moment before its first frame
    env = dict(os.environ, HOME=home, GONA_SCREEN=monitor)
    qs = subprocess.Popen(["quickshell", "-n", "-p", os.path.join(plug, "shell.qml")], env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    threading.Timer(150, qs.kill).start()
    marks, log = {}, []
    for line in qs.stdout:
        log.append(line)
        if "PROMO-START" in line: marks["start"] = time.time() - t0
        if "PROMO-END" in line: marks["end"] = time.time() - t0
        if "PROMO-ERROR" in line or "ERROR" in line and "portal" not in line: print(line.rstrip())
        if "UI-DONE" in line: break
    time.sleep(0.6)
    rec.send_signal(signal.SIGINT)
    rec.wait(20)
    qs.terminate()
    try: qs.wait(5)
    except subprocess.TimeoutExpired: qs.kill()
    json.dump(marks, open(os.path.join(out, "marks.json"), "w"))
    open(os.path.join(out, "instance.log"), "w").write("".join(log))
    print("recorded", raw, marks)
finally:
    shutil.rmtree(work, ignore_errors=True)
