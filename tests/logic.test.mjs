// Unit tests for the plain-JS libraries (layout.js, keys.js, colors.js), which hold no state and
// need no running instance. Run: node --test tests/logic.test.mjs
//
// QML loads them as `.pragma library` scripts with the `Qt` global available; here each file is
// evaluated with that line removed and a small stand-in for the parts of `Qt` it uses.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";

const dir = new URL("../app/", import.meta.url);
const Qt = {
    Key_A: 0x41, Key_Z: 0x5a, Key_0: 0x30, Key_9: 0x39, Key_F1: 0x01000030, Key_F12: 0x0100003b,
    Key_Comma: 0x2c, Key_Period: 0x2e, Key_Slash: 0x2f, Key_Space: 0x20, Key_Plus: 0x2b,
    Key_Equal: 0x3d, Key_Minus: 0x2d, Key_Tab: 0x01000001, Key_Backtab: 0x01000002,
    Key_Home: 0x01000010, Key_End: 0x01000011, Key_Left: 0x01000012, Key_Up: 0x01000013,
    Key_Right: 0x01000014, Key_Down: 0x01000015, Key_PageUp: 0x01000016, Key_PageDown: 0x01000017,
    ShiftModifier: 0x02000000, ControlModifier: 0x04000000, AltModifier: 0x08000000, MetaModifier: 0x10000000,
    color: hex => ({ r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255, b: parseInt(hex.slice(5, 7), 16) / 255 }),
    rgba: (r, g, b, a) => ({ r, g, b, a }),
};
function load(file, names) {
    const src = readFileSync(new URL(file, dir), "utf8").replace(/^\.pragma library\s*$/m, "");
    return new Function("Qt", src + "\nreturn { " + names.join(", ") + " };")(Qt);
}
const Tree = load("lib/layout.js", ["nodeAt", "leafAt", "walkLeaves", "splitAt", "closeAt", "isCross",
    "rotateCrossAt", "cellWidth", "cellHeight", "cellPad", "padTop", "displayIds", "leafRects", "leafMinH", "leafMinW", "fitIcon", "minH", "minW", "effRatio"]);
const KeyCombo = load("lib/keys.js", ["keyName", "comboOf", "comboProblem", "validCombo", "superModeOf", "withSuperMode", "superByHand"]);
const Colors = load("lib/colors.js", ["validValue", "cleanField", "patchField", "parseHex", "toHex", "mix", "over", "luminance", "isLight"]);

const Toml = load("lib/toml.js", ["parse", "stringify"]);
const Fx = load("lib/fx.js", ["NAMES", "TERMINAL", "BASIC", "modeOf", "fromPoint", "hasSide", "slideDir", "bezier", "ease", "bodyOf", "geometry", "screenPoint"]);
const Presets = load("lib/presets.js", ["LIST", "NAMES", "find", "launcherBox"]);
const Config = load("lib/config.js", ["DEFAULTS", "NAMES", "COMMENTS", "toConfig", "fromConfig", "cleanLayout", "legacyEffect"]);

const leaf = (...ids) => ({ type: "leaf", ids });
const m = { icon: 48, labels: true, gap: 8, cellGap: 4, pad: 14 };

test("split, close and address tiles by path", () => {
    const t = leaf("a", "b");
    Tree.splitAt(t, [], "h");
    assert.deepEqual(t, { type: "split", dir: "h", ratio: 0.5, a: leaf("a", "b"), b: leaf() });
    Tree.splitAt(t, ["b"], "v");
    assert.equal(Tree.nodeAt(t, ["b", "a"]).type, "leaf");
    assert.deepEqual(Tree.leafAt(t, ["b"]), {}); // a split, not a leaf
    Tree.closeAt(t, ["a"]); // the sibling (the v split) takes the whole space
    assert.equal(t.dir, "v");
    const ids = [];
    Tree.walkLeaves(t, l => ids.push(l.ids.length));
    assert.deepEqual(ids, [0, 0]);
    const last = leaf("x");
    Tree.closeAt(last, []); // the last tile is only emptied
    assert.deepEqual(last, leaf());
});

test("a cross rotates only while its dividers are aligned", () => {
    const cross = () => ({ type: "split", dir: "v", ratio: 0.4,
        a: { type: "split", dir: "h", ratio: 0.5, a: leaf("1"), b: leaf("2") },
        b: { type: "split", dir: "h", ratio: 0.5, a: leaf("3"), b: leaf("4") } });
    const t = cross();
    assert.ok(Tree.isCross(t));
    assert.ok(Tree.rotateCrossAt(t, [], 0.006));
    assert.equal(t.dir, "h");
    assert.deepEqual([t.a.a.ids, t.a.b.ids, t.b.a.ids, t.b.b.ids], [["1"], ["3"], ["2"], ["4"]]);
    const skewed = cross();
    skewed.b.ratio = 0.7;
    assert.equal(Tree.rotateCrossAt(skewed, [], 0.006), false);
    assert.equal(skewed.dir, "v");
});

test("cells and the Launch all marker", () => {
    assert.equal(Tree.cellWidth(48, true), 100);
    assert.equal(Tree.cellWidth(48, false), 72);
    assert.equal(Tree.cellHeight(48, true), 104);
    const spec = { ids: ["a", "b"], launchAll: true, launchAllIcon: true, launchAllIndex: 9 };
    assert.deepEqual(Tree.displayIds(spec, "*"), ["a", "b", "*"]); // index clamped to the end
    assert.deepEqual(Tree.displayIds({ ids: ["a"], launchAll: true }, "*"), ["a"]); // corner button, no cell
});

test("icons shrink to fit their tile and never go below the floor", () => {
    // labels on: a cell is 2 x size + 4 wide and size + 56 high; gap 4, padding 14
    const fit = (base, n, w, h, labels = true) => Tree.fitIcon(base, n, w, h, labels, 14, 4, 24);
    assert.equal(fit(48, 6, 1000, 200), 48, "room for all: the size it was given");
    assert.equal(fit(48, 0, 10, 10), 48, "no apps: nothing to fit");
    assert.equal(fit(48, 6, 0, 0), 48, "no size yet: as given");
    // 5 apps in one row of 300 x 90: 5 cells of 2s+4 and 4 gaps must fit 300, and s + 56 <= 90
    const s = fit(48, 5, 300, 90);
    assert.ok(s < 48 && s >= 24, "it shrank (" + s + ")");
    assert.ok(5 * (2 * s + 4) + 4 * 4 <= 300 || Math.ceil(5 / Math.floor((300 + 4) / (2 * s + 8))) * (s + 56) + 4 <= 90 + 60, "and the cells fit");
    assert.ok(fit(48, 5, 300, 90) >= fit(48, 9, 300, 90), "more apps never make icons bigger");
    assert.equal(fit(48, 30, 100, 60), 24, "never below the floor: the tile scrolls then");
    assert.equal(fit(30, 3, 1000, 1000), 30, "a size below the floor is left as it is");
    // the result really fits: rows of cells within the height
    for (const n of [1, 3, 5, 8, 13]) for (const [w, h] of [[200, 120], [420, 100], [700, 300]]) {
        const z = fit(56, n, w, h), cols = Math.max(1, Math.min(n, Math.floor((w + 4) / (2 * z + 8))));
        const need = Math.ceil(n / cols) * (z + 56) + (Math.ceil(n / cols) - 1) * 4;
        assert.ok(z === 24 || need <= h, n + " apps in " + w + "x" + h + " at " + z + ": " + need + " px high");
    }
    // without labels a cell is size + 2 x padding square
    assert.equal(fit(64, 4, 400, 60, false), 36, "no labels, a row of four, 60 px high: size + 24 <= 60");
});

test("minimum tile size counts only the installed apps when the shell says which", () => {
    const l = leaf("a", "b", "c", "d", "e", "f", "g");                  // seven listed, two installed
    const some = { ...m, count: ids => ids.slice(0, 2).length };
    assert.equal(Tree.leafMinH(l, 300, some), Tree.leafMinH(leaf("a", "b"), 300, m), "as tall as a tile of the two");
    assert.ok(Tree.leafMinH(l, 300, m) > Tree.leafMinH(l, 300, some), "more than that when all seven count");
    assert.equal(Tree.leafMinW(l, 200, some), Tree.leafMinW(leaf("a", "b"), 200, m));
    assert.equal(Tree.leafMinH(leaf(), 300, { ...m, count: () => 0 }), Tree.leafMinH(leaf("a"), 300, m), "an empty tile needs room for one icon");
});

test("minimum tile size and divider limits", () => {
    // 5 icons of 100 px + 4 gap in a 300 px wide tile: 2 per row, 3 rows of 104 px
    assert.equal(Tree.leafMinH(leaf("1", "2", "3", "4", "5"), 300, m), 44 + 3 * 104 + 2 * 4);
    const split = { type: "split", dir: "h", ratio: 0.05, a: leaf("1", "2"), b: leaf() };
    const r = Tree.effRatio(split, 1000, 400, 0.05, m);
    assert.ok(r * 1000 >= Tree.minW(split.a, 400, m) + m.gap / 2 - 1e-9, "the divider leaves side a its minimum");
    assert.equal(Tree.effRatio(split, 1000, 400, 0.5, m), 0.5); // a ratio that fits is kept
    assert.ok(Tree.minH(split, 1000, m) >= 44 + 104);
});

test("key combinations", () => {
    const ev = (key, ...mods) => ({ key, modifiers: mods.reduce((a, b) => a | b, 0) });
    assert.equal(KeyCombo.comboOf(ev(Qt.Key_Comma, Qt.ControlModifier)), "Ctrl+Comma");
    assert.equal(KeyCombo.comboOf(ev(Qt.Key_Backtab, Qt.ControlModifier)), "Ctrl+Shift+Tab");
    assert.equal(KeyCombo.comboOf(ev(Qt.Key_F1 + 4)), "F5");
    assert.equal(KeyCombo.comboOf(ev(0x01000020)), ""); // a modifier alone (Shift)
    assert.equal(KeyCombo.comboProblem("P"), "Use Ctrl or Alt with the key.");
    assert.equal(KeyCombo.comboProblem("Ctrl+0"), "Reserved for the icon zoom.");
    assert.equal(KeyCombo.comboProblem("Alt+3"), "Reserved for selecting an app of the tile.");
    assert.equal(KeyCombo.comboProblem("Ctrl+Shift+P"), "");
    assert.ok(KeyCombo.validCombo("F12"));
    assert.ok(!KeyCombo.validCombo("Ctrl+F13"));
    assert.ok(!KeyCombo.validCombo(42));
});

test("Super alone: the launcher's own block in bindings.lua", () => {
    const mine = "-- my bindings\nrequire(\"x\")\n";
    assert.equal(KeyCombo.superModeOf(mine), "off");
    const tiles = KeyCombo.withSuperMode(mine, "tiles");
    assert.equal(KeyCombo.superModeOf(tiles), "tiles");
    assert.ok(tiles.startsWith(mine));
    assert.match(tiles, /o\.bind\("SUPER \+ SUPER_L", "Gona Launcher", "omarchy-shell shell toggle gona\.launcher", \{ release = true \}\)/);
    const all = KeyCombo.withSuperMode(tiles, "allApps");
    assert.equal(KeyCombo.superModeOf(all), "allApps");
    assert.equal(all.split(">>> gona-launcher:super").length, 2); // replaced, not added twice
    assert.equal(KeyCombo.withSuperMode(all, "off"), mine);     // off gives the file back as it was
    assert.equal(KeyCombo.withSuperMode("no newline", "off"), "no newline");
    assert.ok(!KeyCombo.superByHand(all), "the launcher's own block is not a binding by hand");
    // a Super-alone binding written by hand is the person's: never removed, and no block is added beside it (two
    // toggles on one release would open and close it at once)
    const hand = mine + "-- tap Super\no.bind(\"SUPER + SUPER_L\", \"Gona Launcher\", \"omarchy-shell shell toggle gona.launcher\", { release = true })\no.bind(\"SUPER + E\", nil, \"nautilus\")\n";
    assert.ok(KeyCombo.superByHand(hand));
    assert.equal(KeyCombo.withSuperMode(hand, "tiles"), hand, "nothing added, nothing removed");
    assert.equal(KeyCombo.withSuperMode(hand, "off"), hand);
    // a block from before the hand-written line: Off still removes only the block
    assert.equal(KeyCombo.withSuperMode(KeyCombo.withSuperMode(mine, "tiles") + "o.bind(\"SUPER + SUPER_L\", nil, \"omarchy-shell shell toggle gona.launcher\")\n", "off"),
                 mine + "o.bind(\"SUPER + SUPER_L\", nil, \"omarchy-shell shell toggle gona.launcher\")\n");
});

test("colour fields", () => {
    assert.ok(Colors.validValue(7, 8) && !Colors.validValue(8, 8) && !Colors.validValue(1.5, 8));
    assert.ok(Colors.validValue("#A0b1c2", 8) && !Colors.validValue("#abc", 8));
    assert.deepEqual(Colors.cleanField({ v: "bogus", a: 40.6 }, 8), { a: 41 });
    assert.equal(Colors.cleanField({ v: 99, a: 200 }, 8), undefined);
    assert.deepEqual(Colors.patchField({ v: 2, a: 50 }, { a: 80 }, 8), { v: 2, a: 80 });
    assert.equal(Colors.patchField({ v: 2 }, null, 8), undefined); // reset
});

test("surfaces: hex round trip, mixing, compositing and which text a surface wants", () => {
    assert.equal(Colors.toHex(Colors.parseHex("#1e66f5")), "#1e66f5");
    assert.equal(Colors.toHex(Colors.mix(Colors.parseHex("#000000"), Colors.parseHex("#ffffff"), 0.5)), "#808080");
    const white = Colors.parseHex("#ffffff"), black = Colors.parseHex("#000000");
    // a see-through white over black is a grey; fully see-through leaves the surface as it was
    assert.equal(Colors.toHex(Colors.over({ ...white, a: 0.5 }, black)), "#808080");
    assert.equal(Colors.toHex(Colors.over({ ...white, a: 0 }, black)), "#000000");
    assert.equal(Colors.toHex(Colors.over(white, black)), "#ffffff"); // no alpha = opaque
    assert.ok(Colors.isLight(Colors.parseHex("#eff1f5")) && !Colors.isLight(Colors.parseHex("#1e1e2e")));
    // the pastel of a mid colour is light, its dark tint is not
    const pink = Colors.parseHex("#d63384");
    assert.ok(Colors.isLight(Colors.mix(white, pink, 0.16)));
    assert.ok(!Colors.isLight(Colors.mix(Colors.parseHex("#181825"), pink, 0.26)));
});

test("toml: reads what a person writes by hand", () => {
    const t = Toml.parse(`
# a comment
version = 1   # trailing comment
name = "a \\"quoted\\" \\u00e9 word"
lit = 'C:\\path'
ratio = 0.5
big = 1_000
neg = -3
on = true
list = [1, 2,
        3, # inside the array
]
mixed = ["a", "b"]
point = { x = 1, y = "two" }
[window]
mode = "top"
[window.panels]
top = [60, 30]
dotted.key = 5
"quoted key" = 1
`);
    assert.equal(t.version, 1);
    assert.equal(t.name, 'a "quoted" \u00e9 word');
    assert.equal(t.lit, "C:\\path");
    assert.deepEqual([t.ratio, t.big, t.neg, t.on], [0.5, 1000, -3, true]);
    assert.deepEqual(t.list, [1, 2, 3]);
    assert.deepEqual(t.point, { x: 1, y: "two" });
    assert.equal(t.window.mode, "top");
    assert.deepEqual(t.window.panels.top, [60, 30]);
    assert.equal(t.window.panels.dotted.key, 5);
    assert.equal(t.window.panels["quoted key"], 1);
});

test("toml: refuses what it does not support, saying which line", () => {
    const bad = {
        "a = 1\nb = \n": /line 2/,
        "a = 1\na = 2": /line 2.*twice/,
        "[t]\n[t]": /line 2.*twice/,
        "[[x]]": /arrays of tables/,
        "a = \"\"\"x\"\"\"": /multi-line/,
        "a = 1979-05-27": /dates/,
        "a = 0xff": /hex/,
        "a = \"open": /unterminated/,
        "a = [1, 2": /expected/,
        "a b = 1": /expected =/,
        "a = 1 2": /unexpected/
    };
    for (const [src, re] of Object.entries(bad)) assert.throws(() => Toml.parse(src), re, src);
});

test("toml: writing and reading again gives the same object", () => {
    const obj = {
        version: 1,
        window: { mode: "top", panels: { top: [60, 30, 40], left: [40, 100] } },
        tiles: { show_names: false, gap: 8, ratio: 0.25 },
        title: "say \"hi\"\n\ttab \\ back \u00e9 \u2603",
        colors: { dark: { accent: { v: "#ff69b4", a: 100 }, bg: { v: 3 } } },
        keys: { allApps: "" },
        empty: {},
        gone: undefined
    };
    const text = Toml.stringify(obj, { "": "top note", window: "the window" });
    assert.match(text, /^# top note\nversion = 1\n/);
    assert.match(text, /# the window\n\[window\]\nmode = "top"/);
    assert.match(text, /\[colors\.dark\.accent\]\nv = "#ff69b4"\na = 100/);
    const back = Toml.parse(text);
    delete obj.empty; delete obj.gone;
    assert.deepEqual(back, obj);
});

test("config: settings and tiles survive the trip through TOML text", () => {
    const layout = { type: "split", dir: "h", ratio: 0.4,
        a: { type: "leaf", ids: ["org.gnome.Nautilus", "zen"], icon: 56, title: "Work", titleBold: true,
             cBorder: { v: "#112233", a: 40 }, cBg: { v: 2 }, centerH: true },
        b: { type: "split", dir: "v", ratio: 0.5, a: { type: "leaf", ids: [] }, b: { type: "leaf", ids: ["x"], launchAll: true } } };
    const settings = { ...Config.DEFAULTS, edge: "top", panels: { top: [60, 30, 40], bottom: [100, 50] }, theme: "light",
        colors: { accent: { v: 4, a: 90 } }, colorsLight: { appBg: { v: "none" } }, keys: { allApps: "Ctrl+K", theme: "" },
        icon: 60, labels: false, iconTheme: "line" };
    const text = Toml.stringify(Config.toConfig(settings, layout), Config.COMMENTS);
    const r = Config.fromConfig(Toml.parse(text));
    assert.deepEqual(r.problems, []);
    assert.deepEqual(r.settings, settings);
    assert.deepEqual(r.layout, layout);
});

test("config: a hand-written file may be partial, wrong values are skipped and reported", () => {
    const r = Config.fromConfig(Toml.parse(`
[window]
mode = "left"
width = "wide"
[tiles]
icon_size = 64
[layout]
type = "split"
dir = "sideways"
`));
    assert.deepEqual(r.settings, { edge: "left", icon: 64 });
    assert.equal(r.layout, null);
    assert.equal(r.problems.length, 2);
    assert.match(r.problems.join("|"), /window\.width.*wrong type/);
    assert.match(r.problems.join("|"), /layout is not a valid/);
    assert.equal(Config.fromConfig(Toml.parse("version = 9")).problems.length, 1);
    // no layout key at all is fine: the caller keeps the tiles it has
    assert.equal(Config.fromConfig({}).layout, null);
    assert.deepEqual(Config.fromConfig({}).problems, []);
});

test("config: the mapping covers every setting once", () => {
    assert.deepEqual([...Config.NAMES].sort(), Object.keys(Config.DEFAULTS).sort());
    const seen = new Set();
    const map = Config.toConfig(Config.DEFAULTS, null);
    for (const [k, v] of Object.entries(map)) if (typeof v === "object") for (const kk of Object.keys(v)) { assert.ok(!seen.has(k + "." + kk)); seen.add(k + "." + kk); }
});

test("config: the tile tree drops what a tile cannot have", () => {
    const t = Config.cleanLayout({ type: "leaf", ids: ["a", 3, "b"], icon: "big", bogus: 1, title: "T", cBg: { v: 1 } });
    assert.deepEqual(t, { type: "leaf", ids: ["a", "b"], title: "T", cBg: { v: 1 } });
    assert.equal(Config.cleanLayout({ type: "split", dir: "h", ratio: 2, a: t, b: t }), null);
    assert.equal(Config.cleanLayout(null), null);
});

test("effects: every curve starts hidden and ends shown, in both directions", () => {
    for (const e of Fx.NAMES) {
        assert.ok(Fx.modeOf(e) > 0, e + " has a shader mode");
        for (const opening of [true, false]) {
            assert.equal(Fx.ease(e, opening, 0), 0, e + " starts at 0");
            assert.equal(Fx.ease(e, opening, 1), 1, e + " ends at 1");
            for (let i = 1; i < 20; i++) assert.ok(Number.isFinite(Fx.ease(e, opening, i / 20)));
        }
    }
    assert.equal(Fx.modeOf("classic"), 0);
    assert.equal(Fx.ease("fluid", true, 1.5), 1, "t is clamped");
});

test("effects: the spring curves overshoot on the way in, the others do not", () => {
    const peak = (e, opening) => Math.max(...Array.from({ length: 200 }, (_, i) => Fx.ease(e, opening, i / 199)));
    assert.ok(peak("fluid", true) > 1.05, "fluid springs past its size");
    assert.ok(peak("bounce", true) > 1.15, "bounce overshoots");
    assert.ok(peak("bounce", false) > 1.0, "bounce winds up before it closes");
    for (const e of ["genie", "dissolve", "glitch", ...Fx.BASIC, ...Fx.TERMINAL]) assert.ok(peak(e, true) <= 1.0001, e + " stays within 0..1");
    // and closing goes down: p falls as the slide falls
    for (const e of Fx.NAMES) assert.ok(Fx.ease(e, false, 0.2) < Fx.ease(e, false, 0.9), e + " closes downward");
});

test("effects: the terminal ones (and glitch) play in place, the others start from a point", () => {
    assert.deepEqual(Fx.NAMES.filter(e => !Fx.fromPoint(e)), [...Fx.BASIC, "glitch", ...Fx.TERMINAL]);
    assert.equal(new Set(Fx.NAMES.map(Fx.modeOf)).size, Fx.NAMES.length, "every effect has its own shader mode");
});

test("effects: bezier is the CSS one", () => {
    assert.ok(Math.abs(Fx.bezier(0.25, 0.1, 0.25, 1, 0.5) - 0.8024) < 0.005, "ease at 0.5 is about 0.80");
    assert.equal(Fx.bezier(0, 0, 1, 1, 0.3) > 0.25 && Fx.bezier(0, 0, 1, 1, 0.3) < 0.35, true, "linear-ish control points stay near the diagonal");
});

test("effects: the launcher's body is a docked panel's area minus the gap on its edge", () => {
    const r = { x: 0, y: 0, w: 1000, h: 300 };
    assert.deepEqual(Fx.bodyOf("top", r, 12), { x: 0, y: 12, w: 1000, h: 288 });
    assert.deepEqual(Fx.bodyOf("bottom", r, 12), { x: 0, y: 0, w: 1000, h: 288 });
    assert.deepEqual(Fx.bodyOf("left", r, 12), { x: 12, y: 0, w: 988, h: 300 });
    assert.deepEqual(Fx.bodyOf("full", r, 12), { x: 12, y: 12, w: 976, h: 276 });
});

test("effects: where they come from", () => {
    const body = { x: 100, y: 100, w: 400, h: 300 };
    // docked: on its own edge, following the bar button along it (kept inside the panel)
    let g = Fx.geometry({ x: 0, y: 0, w: 1000, h: 300 }, "top", { x: 1800, y: 10 });
    assert.deepEqual(g.origin, { x: 1000, y: 0 });
    assert.deepEqual(g.dir, { x: 0, y: 1 });
    g = Fx.geometry({ x: 0, y: 700, w: 1000, h: 300 }, "bottom", null);
    assert.deepEqual(g.origin, { x: 500, y: 1000 });
    assert.deepEqual(g.dir, { x: 0, y: -1 });
    g = Fx.geometry({ x: 0, y: 0, w: 400, h: 1000 }, "right", null);
    assert.deepEqual(g.dir, { x: -1, y: 0 });
    // centred, from the keyboard: grows from the middle, genie is drawn into the bottom like a dock
    g = Fx.geometry(body, "", null);
    assert.deepEqual(g.origin, { x: 300, y: 250 });
    assert.deepEqual(g.genieOrigin, { x: 300, y: 400 });
    assert.deepEqual(g.dir, { x: 0, y: -1 });
    // centred, from a bar button above it: everything comes from the button, genie points down at the window
    g = Fx.geometry(body, "", { x: 300, y: 15 });
    assert.deepEqual(g.origin, { x: 300, y: 15 });
    assert.deepEqual(g.genieOrigin, { x: 300, y: 15 });
    assert.deepEqual(g.dir, { x: 0, y: 1 });
    // a button on the left of it: sideways
    assert.deepEqual(Fx.geometry(body, "", { x: 10, y: 250 }).dir, { x: 1, y: 0 });
    // full screen with the button inside it: the nearest side, the origin brought onto that side
    g = Fx.geometry({ x: 0, y: 0, w: 1920, h: 1080 }, "full", { x: 960, y: 14 });
    assert.deepEqual(g.genieOrigin, { x: 960, y: 0 });
    assert.deepEqual(g.dir, { x: 0, y: 1 });
});

test("effects: the bar button's place on its screen", () => {
    assert.deepEqual(Fx.screenPoint(500, 15, "top", 1920, 1080, 1920, 36), { x: 500, y: 15 });
    assert.deepEqual(Fx.screenPoint(500, 15, "bottom", 1920, 1080, 1920, 36), { x: 500, y: 1059 });
    assert.deepEqual(Fx.screenPoint(15, 300, "right", 1920, 1080, 36, 1080), { x: 1899, y: 300 });
    assert.deepEqual(Fx.screenPoint(15, 300, "left", 1920, 1080, 36, 1080), { x: 15, y: 300 });
});

test("effects: the shader is compiled next to its source", () => {
    const src = readFileSync(new URL("shaders/fx.frag", dir));
    const qsb = readFileSync(new URL("shaders/fx.frag.qsb", dir));
    assert.ok(qsb.length > 1000, "fx.frag.qsb exists (run tools/build-shaders.sh)");
    assert.ok(src.length > 0);
});

test("effects: the side slide and meet come from", () => {
    assert.deepEqual(Fx.slideDir("slide", "top", "left"), { x: 0, y: -1 }, "a docked panel slides from its own edge");
    assert.deepEqual(Fx.slideDir("slide", "right", "top"), { x: 1, y: 0 });
    assert.deepEqual(Fx.slideDir("slide", "", "bottom"), { x: 0, y: 1 }, "a centred window slides from the chosen side");
    assert.deepEqual(Fx.slideDir("slide", "full", "left"), { x: -1, y: 0 });
    assert.deepEqual(Fx.slideDir("meet", "top", "left"), { x: -1, y: 0 }, "meet always follows the chosen side, its axis is what counts");
    assert.ok(Fx.hasSide("slide") && Fx.hasSide("meet") && !Fx.hasSide("blocks"));
});

test("config: the strip buttons start in the Square line style", () => {
    assert.equal(Config.DEFAULTS.iconTheme, "line-square");
});

test("config: the old full-screen animation becomes an effect of every mode", () => {
    assert.equal(Config.legacyEffect("meet", "full"), "meet");
    assert.equal(Config.legacyEffect("stack", "full"), "blocks");
    assert.equal(Config.legacyEffect("fade", "full"), undefined, "fade was the default");
    assert.equal(Config.legacyEffect("meet", "top"), undefined, "it only ever applied to full screen");
    assert.equal(Config.fromConfig({ window: { mode: "full", full_animation: "corners" } }).settings.effect, "corners");
    assert.equal(Config.fromConfig({ window: { mode: "full", full_animation: "corners", effect: "fluid" } }).settings.effect, "fluid", "an effect that is set wins");
    assert.equal(Config.DEFAULTS.effectMs, 700);
});

test("presets: every file parses with nothing skipped, has tiles, and lists an app in one tile only", () => {
    const files = readdirSync(new URL("presets/", dir)).filter(f => f.endsWith(".toml")).map(f => f.slice(0, -5)).sort();
    assert.deepEqual(files, [...Presets.NAMES].sort(), "a file for every preset in presets.js, and no other");
    for (const name of Presets.NAMES) {
        const r = Config.fromConfig(Toml.parse(readFileSync(new URL("presets/" + name + ".toml", dir), "utf8")));
        assert.deepEqual(r.problems, [], name + ": nothing skipped");
        assert.ok(r.layout, name + ": has [layout] (a preset always replaces the tiles)");
        const ids = [];
        Tree.walkLeaves(r.layout, l => ids.push(...l.ids));
        assert.equal(new Set(ids).size, ids.length, name + ": no app in two tiles");
    }
    assert.equal(Presets.LIST[0].recommended, true, "the recommended one comes first (Esc and Enter pick it)");
});

test("presets: the Omarchy one groups by kind and every group but two has an app Omarchy always installs", () => {
    const r = Config.fromConfig(Toml.parse(readFileSync(new URL("presets/omarchy.toml", dir), "utf8")));
    const base = ["chromium", "org.gnome.Nautilus", "foot", "nvim", "btop", "mpv", "imv", "org.gnome.Evince", "localsend", "org.gnome.DiskUtility"];
    const bare = [];
    Tree.walkLeaves(r.layout, l => { if (!l.ids.some(id => base.includes(id))) bare.push(l.ids[0]); });
    // Chat (web apps) and Create (removable preinstalls) can end up empty: the tile says so
    assert.deepEqual(bare, ["WhatsApp", "com.github.PintaProject.Pinta"]);
    const titles = [];
    Tree.walkLeaves(r.layout, l => { if (l.title) titles.push(l.title); });
    assert.deepEqual(titles, ["Web", "Chat", "System", "Dev", "Office", "Media & Play", "Create"], "every tile is titled");
    assert.equal(r.settings.radius, undefined, "square corners: the default, like Omarchy's windows");
    assert.equal(r.settings.effect, "beams");
    Tree.walkLeaves(r.layout, l => assert.ok(l.centerH === true && l.centerV === true, "every tile centres its icons"));
});

test("presets: Omarchy has two rows of tiles of several sizes, Top's are all the same, Dock and Focus are one row", () => {
    const read = n => Config.fromConfig(Toml.parse(readFileSync(new URL("presets/" + n + ".toml", dir), "utf8")));
    const sizes = n => Tree.leafRects(read(n).layout).map(r => r.w.toFixed(3) + "x" + r.h.toFixed(3));
    const om = sizes("omarchy");
    assert.ok(new Set(om).size >= 4, "Omarchy: tiles of several sizes (" + om.join(" ") + ")");
    const rows = read("omarchy").layout, icons = [rows.a, rows.b].map(row => { const v = []; Tree.walkLeaves(row, l => v.push(l.icon || read("omarchy").settings.icon)); return Math.min(...v); });
    assert.ok(icons[0] > icons[1], "the top row has the larger icons (" + icons.join(" and ") + ")");
    assert.equal(new Set(sizes("top")).size, 1, "Top: every tile the same size");
    // one row: every tile of Dock is the full height, each fits its apps side by side at its width on a
    // 1920 px screen, and one row fits the panel's height on a 1080 px one
    const dock = read("dock");
    const pad = dock.settings.padding, icon = dock.settings.icon, outer = Math.min(12, pad);
    const [pw, ph] = dock.settings.panels.bottom;
    const panelW = 1920 * pw / 100 - 2 * outer;
    for (const r of Tree.leafRects(dock.layout)) {
        assert.equal(r.h, 1);
        const need = r.leaf.ids.length * (Tree.cellWidth(icon, false, pad) + 4) - 4 + 2 * pad;
        assert.ok(need <= r.w * panelW - 6, "a Dock group fits one row: " + need + " px in " + Math.round(r.w * panelW) + " px");
        const high = Tree.padTop(r.leaf, pad) + pad + Tree.cellHeight(icon, false, pad) + 2 * outer;
        assert.ok(high <= 1080 * ph / 100, "and the panel's height: " + high + " px in " + 1080 * ph / 100);
        assert.ok(2 * high > 1440 * ph / 100, "but not two rows on a 1440 px screen");
    }
    const focus = read("focus");
    assert.ok(Tree.leafRects(focus.layout).length === 1 && focus.layout.ids.length * (Tree.cellWidth(focus.settings.icon, true, 14) + 4) + 28 + 24 <= focus.settings.width, "Focus: its apps fit one row");
});

test("presets: where the launcher sits for the previews", () => {
    const near = (a, b) => Object.keys(b).forEach(k => assert.ok(Math.abs(a[k] - b[k]) < 1e-9, k + ": " + a[k] + " vs " + b[k]));
    near(Presets.launcherBox({}, 1800, 1000), { x: 0.25, y: 0.19, w: 0.5, h: 0.62 });
    near(Presets.launcherBox({ edge: "bottom", panels: { bottom: [70, 16] }, offset: 0 }, 1000, 1000), { x: 0.15, y: 0.84, w: 0.7, h: 0.16 });
    near(Presets.launcherBox({ edge: "left" }, 1000, 1000), { x: 0.012, y: 0, w: 0.4, h: 1 });
    near(Presets.launcherBox({ width: 5000, height: 5000 }, 1000, 1000), { x: 0.04, y: 0.04, w: 0.92, h: 0.92 });
});

test("tiles as rectangles: fractions of the whole, in tile order", () => {
    const t = { type: "split", dir: "v", ratio: 0.5, a: leaf("a"), b: { type: "split", dir: "h", ratio: 0.25, a: leaf("b"), b: leaf("c") } };
    assert.deepEqual(Tree.leafRects(t).map(r => [r.leaf.ids[0], r.x, r.y, r.w, r.h]),
                     [["a", 0, 0, 1, 0.5], ["b", 0, 0.5, 0.25, 0.5], ["c", 0.25, 0.5, 0.75, 0.5]]);
    assert.deepEqual(Tree.leafRects(leaf()).map(r => [r.x, r.y, r.w, r.h]), [[0, 0, 1, 1]]);
});

test("padding: the default keeps the sizes there were, less brings the icons to the border", () => {
    assert.deepEqual([Tree.cellWidth(48, false), Tree.cellWidth(48, false, 14), Tree.cellHeight(48, false, 14)], [72, 72, 72]);
    assert.deepEqual([Tree.cellWidth(48, false, 4), Tree.cellWidth(48, false, 0), Tree.cellWidth(48, true, 0)], [56, 48, 100], "names keep their width");
    assert.deepEqual([Tree.padTop({}, 14), Tree.padTop({}, 7), Tree.padTop({}, 0), Tree.padTop({}, 24)], [30, 15, 0, 30], "untitled: room for the ⋯ button shrinks with it");
    assert.deepEqual([Tree.padTop({ title: "Web" }, 0), Tree.padTop({ launchAll: true }, 2), Tree.padTop({ launchAll: true, launchAllIcon: true }, 2)], [30, 30, 4.285714285714286], "a title or the Launch all corner keep theirs");
    const tight = Object.assign({}, m, { labels: false, pad: 0 });
    assert.equal(Tree.leafMinH(leaf("a", "b"), 500, tight), 48, "at 0 a row of icons is exactly one icon high");
});

test("presets: the launcher's place reads a panel size that is not a plain Array (a list from QML)", () => {
    const list = { 0: 48, 1: 8, 2: 10, length: 3 }; // what a JS array becomes through a QML `var` property
    const b = Presets.launcherBox({ edge: "bottom", panels: { bottom: list }, offset: 0 }, 1000, 1000);
    assert.deepEqual([b.w, b.h], [0.48, 0.08]);
});

test("corners: square by default, and no preset rounds them", () => {
    assert.equal(Config.DEFAULTS.radius, 0);
    for (const name of Presets.NAMES) {
        const r = Config.fromConfig(Toml.parse(readFileSync(new URL("presets/" + name + ".toml", dir), "utf8")));
        assert.equal(r.settings.radius === undefined ? Config.DEFAULTS.radius : r.settings.radius, 0, name);
    }
});
