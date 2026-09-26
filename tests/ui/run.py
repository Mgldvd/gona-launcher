#!/usr/bin/env python3
"""Runs the interface tests in tests/ui/*.body against a throw-away copy of the plugin.

Each test is a body of QML/JS run inside a QtTest TestCase that is injected into a copy of Overlay.qml
(or of OptionsMenu.qml), so it sees the launcher's own ids (`root`, `dockedArea`, `floatingMenu`, ...)
and sends real key and mouse events to the real windows. A copy of the plugin runs in its own
Quickshell instance with its own HOME, so ~/.config/gona-launcher is never touched. It needs the running
Wayland session (Quickshell's windows are layer-shell surfaces, there is no headless backend): while a
test runs, full-screen transparent surfaces exist for a few seconds and the launcher takes the keyboard
focus, so do not type or click meanwhile.

A test starts with directives, one per line:
    // edge: top            the window mode the run starts in ("" = centered); repeated: one run per value
    // fixture: none        none (defaults, the default) | legacy (window.json + layout.json) | broken (invalid config.toml)
                         | first-run (no config.toml at all: the welcome screen shows; "none" writes a comment-only
                         config.toml so it does not)
    // where: launcher      launcher (TestCase inside the launcher window, the default) | menu (inside OptionsMenu)
    // omarchy: light       the active Omarchy theme in the test's HOME: none (no theme, the default) | dark | light | generated
    // config: [appearance]\nmode = "auto"   extra lines for config.toml
    // profile: work        a profile "work" (icon_size 72) already saved and in use
    // usage: {"app-id": {"n": 3, "last": 1}}   launch counts already in usage.json
    // hypr: yes            a ~/.config/hypr/bindings.lua in the test's HOME (Omarchy's), for the Super key
    // open: yes            yes (open the launcher, and the menu for `where: menu`) | no
Helpers in the body: ok(cond, msg), eq(actual, expected, msg), findAll(item, predicate), click(item),
finish(). The body runs after 1 s and must end the run with finish().
Usage: tests/ui.sh [name ...]   (no names = all)"""
import os, re, shutil, subprocess, sys, tempfile, textwrap, threading

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))

HELPERS = """
            function ok(cond, msg) { console.log((cond ? "UI-PASS " : "UI-FAIL ") + msg); }
            function eq(actual, expected, msg) {
                const same = JSON.stringify(actual) === JSON.stringify(expected);
                console.log((same ? "UI-PASS " : "UI-FAIL ") + msg + (same ? "" : "  (got " + JSON.stringify(actual) + ", wanted " + JSON.stringify(expected) + ")"));
            }
            function findAll(item, pred) {
                const out = [];
                (function walk(it) { for (let i = 0; i < it.children.length; i++) { const c = it.children[i]; if (pred(c)) out.push(c); walk(c); } })(item);
                return out;
            }
            function click(item) { mouseClick(item); wait(120); }
            function finish() { console.log("UI-DONE"); }
"""

def directives(text):
    d = {"edge": [], "fixture": "none", "where": "launcher", "open": "yes", "omarchy": "none", "config": "", "usage": "", "profile": "", "hypr": "no"}
    for line in text.splitlines():
        m = re.match(r"//\s*(edge|fixture|where|open|omarchy|config|usage|profile|hypr):\s*(.*?)\s*$", line)
        if not m:
            if line.strip() and not line.startswith("//"): break
            continue
        if m.group(1) == "edge": d["edge"].append(m.group(2).strip('"'))
        else: d[m.group(1)] = m.group(2)
    if not d["edge"]: d["edge"] = [None]
    return d

def build(body, d, edge, work):
    plug = os.path.join(work, "plug"); home = os.path.join(work, "home")
    cfg = os.path.join(home, ".config", "gona-launcher")
    os.makedirs(cfg)
    shutil.copytree(ROOT, plug, ignore=shutil.ignore_patterns(".git", "tests", ".agents", ".claude", "docs", "tools"))
    if d["fixture"] == "legacy":
        for f in ("window.json", "layout.json"):
            shutil.copy(os.path.join(HERE, "fixtures", f), cfg)
    elif d["fixture"] == "broken":
        open(os.path.join(cfg, "config.toml"), "w").write('[window\nmode = "top"\n')
    if edge is not None:
        open(os.path.join(cfg, "config.toml"), "w").write('[window]\nmode = "%s"\n' % edge)
    if d["config"]:  # extra text for config.toml (\n written as \\n in the directive)
        open(os.path.join(cfg, "config.toml"), "a").write(d["config"].replace("\\n", "\n") + "\n")
    if d["profile"]:  # a saved profile, in use: its name; its file has a distinctive icon_size (72)
        os.makedirs(os.path.join(cfg, "profiles"))
        open(os.path.join(cfg, "profiles", d["profile"] + ".toml"), "w").write('[tiles]\nicon_size = 72\n')
        state = os.path.join(home, ".local", "state", "gona-launcher")
        os.makedirs(state, exist_ok=True)
        open(os.path.join(state, "profile"), "w").write(d["profile"])
    if d["usage"]:  # the launch counts already there: a JSON object
        state = os.path.join(home, ".local", "state", "gona-launcher")
        os.makedirs(state, exist_ok=True)
        open(os.path.join(state, "usage.json"), "w").write(d["usage"])
    conf = os.path.join(cfg, "config.toml")
    if d["fixture"] == "none" and not os.path.exists(conf):  # an existing (empty) configuration: no welcome screen
        open(conf, "w").write("# ui test\n")
    if d["hypr"] == "yes":  # Omarchy's own bindings file, with a line of the person's that must survive
        hypr = os.path.join(home, ".config", "hypr")
        os.makedirs(hypr)
        open(os.path.join(hypr, "bindings.lua"), "w").write('-- mine\no.bind("SUPER + E", "Files", "nautilus")\n')
    # a hyprctl that does nothing, first on PATH: a test must never make the real Hyprland reload
    bindir = os.path.join(work, "bin")
    os.makedirs(bindir)
    open(os.path.join(bindir, "hyprctl"), "w").write("#!/bin/sh\nexit 0\n")
    os.chmod(os.path.join(bindir, "hyprctl"), 0o755)
    if d["omarchy"] != "none":  # the active Omarchy theme: fixtures/omarchy-<dark|light>.toml
        theme = os.path.join(home, ".local", "state", "omarchy", "current", "theme")
        os.makedirs(theme)
        shutil.copy(os.path.join(HERE, "fixtures", "omarchy-%s.toml" % d["omarchy"]), os.path.join(theme, "colors.toml"))
    test = ('        TestCase {\n            id: t\n            name: "ui"\n            when: %s\n%s\n'
            '            function test_body() {\n                wait(1000);\n%s\n            }\n        }\n')
    if d["where"] == "menu":
        target, anchor, when = "app/menus/OptionsMenu.qml", "    visible: open\n", "menu.visible && menu.width > 0"
    else:
        target, anchor, when = "app/Overlay.qml", "        MouseArea { anchors.fill: parent; onClicked: root.hide() }\n", "root.opened"
    path = os.path.join(plug, target)
    s = open(path).read()
    assert anchor in s, "anchor not found in " + target
    s = s.replace("import QtQuick\n", "import QtQuick\nimport QtTest\n", 1)
    s = s.replace(anchor, anchor + test % (when, HELPERS, textwrap.indent(body, " " * 16)), 1)
    open(path, "w").write(s)
    opener = 'o.open(\'{"tab":"tiles"}\')' if d["where"] == "menu" else 'o.open("{}")'
    if d["open"] == "no": opener = ""
    open(os.path.join(plug, "shell.qml"), "w").write(
        "import QtQuick\nimport Quickshell\nimport \"app\"\nShellRoot { Overlay { id: o; Component.onCompleted: { %s } } }\n" % opener)
    return plug, home

def run_one(name, body, d, edge):
    work = tempfile.mkdtemp(prefix="gona-ui-")
    try:
        plug, home = build(body, d, edge, work)
        env = dict(os.environ, HOME=home, PATH=os.path.join(work, "bin") + os.pathsep + os.environ["PATH"])
        # read the log as it comes and stop the instance when the test says it is done: quitting from
        # inside a QtTest handler crashes Quickshell
        p = subprocess.Popen(["quickshell", "-n", "-p", os.path.join(plug, "shell.qml")], env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lines = []
        timer = threading.Timer(60, p.kill); timer.start()
        for line in p.stdout:
            lines.append(line)
            if "UI-DONE" in line: break
        timer.cancel(); p.terminate()
        try: p.wait(5)
        except subprocess.TimeoutExpired: p.kill()
        out = "".join(lines)
        if "UI-DONE" not in out: out += "\nUI-FAIL timed out (the test never called finish())"
        out = re.sub(r"\x1b\[[0-9;]*m", "", out)
        results = []
        for line in out.splitlines():
            m = re.search(r"(UI-(?:PASS|FAIL)) (.*)", line)
            if m: results.append((m.group(1) == "UI-PASS", m.group(2)))
            elif re.search(r"ERROR|TypeError|ReferenceError|Syntax error", line) and "portal" not in line:
                results.append((False, "log: " + line.split(": ", 1)[-1][:160]))
        if "UI-DONE" not in out and not any(not ok for ok, _ in results):
            results.append((False, "the test never reached finish()"))
        return results
    finally:
        shutil.rmtree(work, ignore_errors=True)

def main():
    want = sys.argv[1:]
    files = sorted(f for f in os.listdir(HERE) if f.endswith(".body") and (not want or f[:-5] in want))
    if not files: print("no tests"); return 1
    failed = 0
    for f in files:
        body = open(os.path.join(HERE, f)).read()
        d = directives(body)
        for edge in d["edge"]:
            label = f[:-5] + ("" if edge is None else " [mode=%r]" % edge)
            results = run_one(f[:-5], body, d, edge)
            bad = [m for ok, m in results if not ok]
            print(("  OK  " if not bad else "FAIL  ") + label + "  (%d checks)" % len(results))
            for m in bad: print("        - " + m)
            failed += len(bad)
    print("\n%s" % ("all passed" if not failed else "%d failed" % failed))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
