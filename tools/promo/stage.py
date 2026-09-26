"""The promo stage, shared by record.py (the video) and stills.py (the README screenshots): a throw-away copy of the
plugin (the UI test runner's) with the promo backdrop and overlay, the curated demo configuration, this machine's apps and
icons, and launching and the power buttons switched off so a demo can never run or shut down anything."""
import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tests", "ui"))
import run  # the UI test runner: it knows how to build a throw-away copy of the plugin


def focused_monitor():
    """The monitor Hyprland has focused: where the launcher opens, so where the stage and the recording must be."""
    mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
    return next((m["name"] for m in mons if m.get("focused")), mons[0]["name"])


def build(body, work):
    """Builds the stage for `body` (a director script) in the folder `work`; returns (plugin folder, HOME)."""
    plug, home = run.build(body, run.directives(body), None, work)
    for f in ("PromoBackdrop.qml", "PromoOverlay.qml", "gona-launcher.png"):
        shutil.copy(os.path.join(HERE, f), os.path.join(plug, "app"))
    subprocess.check_call(["node", os.path.join(HERE, "demo-config.mjs"), os.path.join(home, ".config", "gona-launcher")], stdout=subprocess.DEVNULL)
    # a demo must never launch or shut down anything for real
    p = os.path.join(plug, "app", "Overlay.qml"); s = open(p).read()
    a = "    function launchApp(entry) { noteLaunch(entry.id); entry.execute(); }"
    assert a in s
    s = s.replace(a, "    function launchApp(entry) { }")
    b = "    function powerAction(flag) {"
    assert b in s
    s = s.replace(b, "    function powerAction(flag) { return; }\n    function powerActionReal(flag) {")
    open(p, "w").write(s)
    # the apps of this machine, with their icons: the real desktop entries and icon theme, read only
    real = os.path.expanduser("~")
    os.makedirs(os.path.join(home, ".local"), exist_ok=True)
    os.symlink(os.path.join(real, ".local", "share"), os.path.join(home, ".local", "share"))
    for d in ("gtk-3.0", "gtk-4.0"):
        if os.path.isdir(os.path.join(real, ".config", d)):
            shutil.copytree(os.path.join(real, ".config", d), os.path.join(home, ".config", d))
    return plug, home
