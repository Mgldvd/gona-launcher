.pragma library

// Key combinations for the configurable shortcuts (shell.qml keeps the actions and the user's
// choices; see "Keyboard shortcuts" in CLAUDE.md). A combination is text such as "Ctrl+Shift+P":
// modifiers in the order Ctrl, Alt, Shift, Meta, then the key.

// the name of a key in a combination, "" when it cannot be part of one
function keyName(k) {
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
    if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
    switch (k) {
    case Qt.Key_Comma: return "Comma";
    case Qt.Key_Period: return "Period";
    case Qt.Key_Slash: return "Slash";
    case Qt.Key_Left: return "Left";
    case Qt.Key_Right: return "Right";
    case Qt.Key_Up: return "Up";
    case Qt.Key_Down: return "Down";
    case Qt.Key_PageUp: return "PgUp";
    case Qt.Key_PageDown: return "PgDown";
    case Qt.Key_Home: return "Home";
    case Qt.Key_End: return "End";
    case Qt.Key_Tab: case Qt.Key_Backtab: return "Tab";
    case Qt.Key_Space: return "Space";
    case Qt.Key_Plus: return "Plus";
    case Qt.Key_Equal: return "Equal";
    case Qt.Key_Minus: return "Minus";
    }
    return "";
}
// the combination a key event makes, or "" (only a modifier, or a key that cannot be used)
function comboOf(event) {
    const name = keyName(event.key);
    if (name === "") return "";
    const m = event.modifiers;
    const shift = (m & Qt.ShiftModifier) || event.key === Qt.Key_Backtab;
    return ((m & Qt.ControlModifier) ? "Ctrl+" : "") + ((m & Qt.AltModifier) ? "Alt+" : "")
         + (shift ? "Shift+" : "") + ((m & Qt.MetaModifier) ? "Meta+" : "") + name;
}
// "" when the combination may be assigned, else why not. It must contain Ctrl or Alt (F-keys may
// stand alone), because plain letters and digits start the type-to-filter; Ctrl +/-/0 (zoom) and
// Alt+1..9 (select the nth app of the tile) are fixed.
function comboProblem(combo) {
    const parts = combo.split("+");
    const key = parts[parts.length - 1];
    const mods = parts.slice(0, -1);
    if (!mods.every(m => ["Ctrl", "Alt", "Shift", "Meta"].includes(m))) return "That is not a valid combination.";
    if (!(mods.includes("Ctrl") || mods.includes("Alt") || /^F\d+$/.test(key))) return "Use Ctrl or Alt with the key.";
    if (["Plus", "Equal", "Minus", "0"].includes(key) && mods.includes("Ctrl")) return "Reserved for the icon zoom.";
    if (mods.length === 1 && mods[0] === "Alt" && /^[1-9]$/.test(key)) return "Reserved for selecting an app of the tile.";
    return "";
}
// is this a combination the code could have produced (used to check saved values)
function validCombo(combo) {
    if (typeof combo !== "string" || combo === "") return false;
    const key = combo.split("+").pop();
    const known = /^([A-Z0-9]|F([1-9]|1[0-2])|Comma|Period|Slash|Left|Right|Up|Down|PgUp|PgDown|Home|End|Tab|Space)$/;
    return known.test(key) && comboProblem(combo) === "";
}

// ---- Super alone: the Hyprland binding that opens the launcher (⚙ > Keys, "Open with Super")
// The launcher keeps it as a marked block of its own in ~/.config/hypr/bindings.lua, so it can find,
// change and remove it without touching the person's other lines. `mode` is "off", "tiles" or "allApps".
const SUPER_BEGIN = "-- >>> gona-launcher:super >>>";
const SUPER_END = "-- <<< gona-launcher:super <<<";
// what the block in `text` opens ("off" when there is none)
function superModeOf(text) {
    const s = String(text || "");
    const i = s.indexOf(SUPER_BEGIN), j = s.indexOf(SUPER_END);
    if (i < 0 || j < i) return "off";
    return s.slice(i, j).indexOf("allApps") >= 0 ? "allApps" : "tiles";
}
// `text` with the block set to `mode` (removed for "off"); the rest of the file is kept as it was
function withSuperMode(text, mode) {
    let s = String(text || "");
    const i = s.indexOf(SUPER_BEGIN), j = s.indexOf(SUPER_END);
    if (i >= 0 && j > i) {
        let end = j + SUPER_END.length;
        if (s.charAt(end) === "\n") end++;
        let start = i;
        if (start > 0 && s.charAt(start - 1) === "\n" && (start < 2 || s.charAt(start - 2) === "\n")) start--; // the blank line before it
        s = s.slice(0, start) + s.slice(end);
    }
    if (mode !== "tiles" && mode !== "allApps") return s;
    // a Super-alone binding for this launcher written by hand would fire together with the block (two toggles on
    // one release: it opens and closes at once), so the block takes its place
    s = s.replace(/^[ \t]*[\w.]*bind\(.*SUPER_L.*gona\.launcher.*\)[ \t]*\n?/gm, "");
    const cmd = "omarchy-shell shell toggle gona.launcher" + (mode === "allApps" ? " '{\"allApps\":true}'" : "");
    if (s !== "" && !s.endsWith("\n")) s += "\n";
    return s + "\n" + SUPER_BEGIN + "\n"
         + "-- Press and release Super alone to open Gona Launcher (set in its ⚙ > Keys; \"Off\" there removes this)\n"
         + "o.bind(\"SUPER + SUPER_L\", \"Gona Launcher\", " + JSON.stringify(cmd) + ", { release = true })\n"
         + SUPER_END + "\n";
}
