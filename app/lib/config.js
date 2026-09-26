.pragma library

// What config.toml holds and how it maps to the launcher's own settings (Overlay.qml keeps them under
// short names, `icon`, `gap`, `searchAll`...; the file uses readable sections and names). Plain
// functions, no state; toml.js reads and writes the text itself.
//
//   toConfig(settings, layout)  the nested object to hand to Toml.stringify()
//   fromConfig(cfg)             { settings, layout, problems } from what Toml.parse() returned:
//                               `settings` has only the values present and of the right type, `layout`
//                               is null when the file has no (valid) tiles, `problems` says what was skipped

// The value each setting starts with, under its short name (the same as the adapter in Overlay.qml).
var DEFAULTS = {
    width: 900, height: 620, edge: "", offset: 12, speed: 110, effect: "classic", effectMs: 700, closeAnim: true, reduceMotion: false, fullFrom: "top", panels: {},
    icon: 48, labels: true, gap: 8, padding: 14, radius: 0, borderWidth: 2, tileButtons: "pause",
    searchAll: false, searchLabels: true, filterFontSize: 14,
    allAppsButton: false, powerOffButton: false, restartButton: false, logoutButton: false,
    powerButtonSize: 34, iconTheme: "line-square",
    theme: "dark", followTheme: true, trackUsage: true, usageOrder: "most_used", showUsageRow: false, usageRowCount: 6, nextToBar: false, showProfileButtons: false, profileLabels: "numbers", menuScale: 100, colors: {}, colorsLight: {}, keys: {}
};

// [short name, section, key in the file]; the order is the order in the file
var MAP = [
    ["edge", "window", "mode"],
    ["width", "window", "width"],
    ["height", "window", "height"],
    ["offset", "window", "offset"],
    ["speed", "window", "slide_speed"],
    ["effect", "window", "effect"],
    ["effectMs", "window", "effect_ms"],
    ["closeAnim", "window", "animate_close"],
    ["reduceMotion", "window", "reduce_motion"],
    ["fullFrom", "window", "full_from"],
    ["panels", "window", "panels"],
    ["nextToBar", "window", "next_to_bar_button"],
    ["icon", "tiles", "icon_size"],
    ["labels", "tiles", "show_names"],
    ["gap", "tiles", "gap"],
    ["padding", "tiles", "padding"],
    ["radius", "tiles", "corner_radius"],
    ["borderWidth", "tiles", "border_width"],
    ["tileButtons", "tiles", "buttons"],
    ["searchAll", "search", "all_apps"],
    ["searchLabels", "search", "show_names"],
    ["filterFontSize", "search", "text_size"],
    ["allAppsButton", "buttons", "all_apps"],
    ["powerOffButton", "buttons", "shut_down"],
    ["restartButton", "buttons", "restart"],
    ["logoutButton", "buttons", "log_out"],
    ["powerButtonSize", "buttons", "size"],
    ["iconTheme", "buttons", "style"],
    ["showProfileButtons", "buttons", "profiles"],
    ["profileLabels", "buttons", "profile_labels"],
    ["trackUsage", "usage", "track"],
    ["usageOrder", "usage", "order"],
    ["showUsageRow", "usage", "show_row"],
    ["usageRowCount", "usage", "row_count"],
    ["theme", "appearance", "mode"],
    ["followTheme", "appearance", "follow_omarchy"],
    ["menuScale", "appearance", "menu_size"],
    ["colors", "colors", "dark"],
    ["colorsLight", "colors", "light"],
    ["keys", "keys", null]
];

var NAMES = MAP.map(function (m) { return m[0]; });

var VERSION = 1;

var COMMENTS = {
    "": "Gona Launcher: settings and tiles in one file.\n"
        + "Edit it while the launcher is closed, or use Import / Export in the settings menu (Profiles tab).\n"
        + "A value that is missing or invalid falls back to its default.",
    "window": "Where the launcher opens. mode: \"\" (centered), \"top\", \"bottom\", \"left\", \"right\" or \"full\". reduce_motion: true opens and closes it at once, with no effect or slide. effect: how it comes in, \"classic\" (a panel slides, full screen fades, a centered window appears at once; slide_speed is its length in ms) or an effect that works in every mode (effect_ms is its length): \"fade\", \"slide\", \"meet\", \"corners\", \"blocks\", \"fluid\", \"bounce\", \"genie\", \"dissolve\", \"glitch\", \"matrix\", \"decrypt\", \"synthgrid\", \"spotlights\", \"laser\", \"blackhole\", \"fireworks\", \"rain\", \"beams\" or \"vhs\". full_from: the side slide and meet come from. animate_close: false makes closing instant.",
    "window.panels": "Per position: [width %, height %] and optionally the edge offset in px as a third number. next_to_bar_button: a panel opened from the bar button is centred on it.",
    "tiles": "How the tiles look. padding: the room inside a tile and around its icons, 0-24 px (0: the icons almost touch the border). buttons: when a tile shows its ＋ and ⋯ buttons, \"pause\" (after the pointer rests on it for a moment) or \"click\" (never: right-click the tile instead).",
    "search": "Typing to filter, and searching every installed app.",
    "buttons": "The strip with the all-apps and power buttons. style: grid, pastel, carbon, line, line-square, circle or metro. profiles: the saved profiles (up to 5, the default included) as buttons in the strip, labelled by profile_labels: \"numbers\", \"letters\" or \"roman\". These two are shared by every profile.",
    "usage": "track: count the apps launched from here (kept in ~/.local/state/gona-launcher/usage.json, on this machine only). order: \"name\", \"most_used\" or \"recent\", for the all-apps list and the typed search and the row. show_row: a row of the apps used most (or last) above the tiles, row_count of them (3-10).",
    "appearance": "mode: \"dark\", \"light\" or \"auto\" (follows Omarchy's own light/dark setting). follow_omarchy: use the colors of the active Omarchy theme. menu_size is the size of the settings menus in %.",
    "colors": "Colours of each mode. A field is { v = ..., a = ... }: v is \"system\", \"none\", a palette number 0-7 or \"#rrggbb\"; a is the opacity 0-100.",
    "keys": "Shortcuts that differ from the defaults. \"\" turns one off.",
    "layout": "The tiles: a split (dir \"h\" or \"v\", ratio, and two halves a and b) or a leaf (the apps in it, by desktop id)."
};

function plain(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
function isObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }

// --------------------------------------------------------------------------------------- tiles
var LEAF_KEYS = [["icon", "number"], ["title", "string"], ["titleAlign", "string"], ["titleFont", "string"],
                 ["titleBold", "boolean"], ["titleItalic", "boolean"], ["centerH", "boolean"], ["centerV", "boolean"],
                 ["launchAll", "boolean"], ["launchAllIcon", "boolean"], ["launchAllIndex", "number"]];

// A copy of a tile tree with only what a tile can have, keys in a readable order; null when it is not
// a tree at all. (Colour fields are kept as they are: Overlay.cleanField() checks them where used.)
function cleanLayout(node, depth) {
    const d = depth || 0;
    if (!isObject(node) || d > 40) return null;
    if (node.type === "leaf") {
        if (!Array.isArray(node.ids)) return null;
        const out = { type: "leaf", ids: node.ids.filter(function (s) { return typeof s === "string"; }) };
        LEAF_KEYS.forEach(function (k) { if (typeof node[k[0]] === k[1]) out[k[0]] = node[k[0]]; });
        ["cBorder", "cBg"].forEach(function (k) { if (isObject(node[k])) out[k] = plain(node[k]); });
        return out;
    }
    if (node.type === "split") {
        if (node.dir !== "h" && node.dir !== "v") return null;
        if (typeof node.ratio !== "number" || !(node.ratio >= 0 && node.ratio <= 1)) return null;
        const a = cleanLayout(node.a, d + 1);
        const b = cleanLayout(node.b, d + 1);
        return a && b ? { type: "split", dir: node.dir, ratio: node.ratio, a: a, b: b } : null;
    }
    return null;
}

// --------------------------------------------------------------------------------------- mapping
function toConfig(settings, layout) {
    const cfg = { version: VERSION };
    MAP.forEach(function (m) {
        const v = plain(settings[m[0]]);
        if (v === undefined) return;
        if (m[2] === null) { cfg[m[1]] = v; return; }
        if (m[0] === "colors" || m[0] === "colorsLight") {
            if (!cfg.colors) cfg.colors = {};
            cfg.colors[m[2]] = v;
            return;
        }
        if (!cfg[m[1]]) cfg[m[1]] = {};
        cfg[m[1]][m[2]] = v;
    });
    const tree = cleanLayout(plain(layout));
    if (tree) cfg.layout = tree;
    return cfg;
}

// Before the basic styles became effects of every mode, full screen had its own `full_animation`; what it said
// becomes the effect (undefined when it said nothing that matters: fade was the default, and it was only for full screen)
function legacyEffect(fullAnimation, mode) {
    if (mode !== "full") return undefined;
    return { slide: "slide", meet: "meet", corners: "corners", stack: "blocks" }[fullAnimation];
}

function typeOk(name, v) {
    const want = DEFAULTS[name];
    if (isObject(want)) return isObject(v);
    return typeof v === typeof want && (typeof v !== "number" || isFinite(v));
}

function fromConfig(cfg) {
    const settings = {};
    const problems = [];
    if (!isObject(cfg)) return { settings: settings, layout: null, problems: ["the file is not a TOML table"] };
    if (cfg.version !== undefined && cfg.version !== VERSION)
        problems.push("version " + cfg.version + " is not the one this launcher writes (" + VERSION + ")");
    MAP.forEach(function (m) {
        const name = m[0];
        let v;
        if (m[2] === null) v = cfg[m[1]];
        else if (name === "colors" || name === "colorsLight") v = isObject(cfg.colors) ? cfg.colors[m[2]] : undefined;
        else v = isObject(cfg[m[1]]) ? cfg[m[1]][m[2]] : undefined;
        if (v === undefined) return;
        if (typeOk(name, v)) settings[name] = plain(v);
        else problems.push((m[2] === null ? m[1] : m[1] + "." + m[2]) + " has the wrong type, ignored");
    });
    if (settings.effect === undefined && isObject(cfg.window)) {
        const le = legacyEffect(cfg.window.full_animation, settings.edge !== undefined ? settings.edge : cfg.window.mode);
        if (le !== undefined) settings.effect = le;
    }
    let layout = null;
    if (cfg.layout !== undefined) {
        layout = cleanLayout(plain(cfg.layout));
        if (!layout) problems.push("layout is not a valid tile tree, ignored");
    }
    return { settings: settings, layout: layout, problems: problems };
}
