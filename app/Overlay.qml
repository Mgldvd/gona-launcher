import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "launcher"
import "menus"
import "lib/layout.js" as Tree
import "lib/keys.js" as KeyCombo
import "lib/colors.js" as Colors
import "lib/toml.js" as Toml
import "lib/config.js" as Config
import "lib/fx.js" as Fx
import "lib/presets.js" as Presets

// Gona Launcher: your apps in a tiling layout. Split a tile right/down; every tile is a group.
// An Omarchy shell "overlay" plugin: it lives inside the shared omarchy-shell process, not a
// window of its own. The shell calls open(payload)/close() (see the bottom of this file); the
// generic `omarchy-shell shell toggle|summon|hide gona.launcher` commands drive those.
//
// This file holds the state and the logic (settings, layout tree, filter and keyboard selection,
// showing/hiding) and the one overlay window. What is drawn lives in the other files
// (launcher/ for the launcher window, menus/ for the two menus; see "Repository layout" in CLAUDE.md):
//   LauncherContent  everything inside the launcher card       Node          a tile or a split (recursive)
//   AppCell          one app icon                               SearchResults matches among all apps
//   Picker           the "add apps" grid                        ColorField    one colour field (see below)
//   OptionsMenu      the ⚙ menu (global options)                 TileMenu      the ⋯ menu of one tile
Item {
    id: root

    //---------------------------------------------------------- state
    // The layout is a tree: {type:"leaf", ids:[appIds], ...} or {type:"split", dir:"h"|"v", ratio, a, b}.
    // A leaf may also carry: icon (its own icon size), cBorder / cBg (its own border and background
    // colour, see "the colour system" below), title / titleAlign / titleFont / titleBold / titleItalic, centerH / centerV (alignment).
    property var layout: ({ type: "leaf", ids: [] })
    property var pickingPath: null // tile that the app picker is adding to, or null
    // Resizing tiles (dividers and cross handles) only works while this is on, so nothing moves by
    // accident. Toggled in the ⚙ options menu; Esc or hiding the window turns it off.
    property bool resizeMode: false
    property Item dragOverlay: null // the content registers its drag layer here (LauncherContent.qml)

    //---------------------------------------------------------- settings (all saved in config.toml)
    // last card size, restored on start and saved (debounced) whenever it changes
    property alias winW: saved.width
    property alias winH: saved.height

    // icon size (px); every cell dimension is derived from it
    property alias iconSize: saved.icon
    function clampIcon(v) { return Math.max(24, Math.min(96, Math.round(v / 4) * 4)); }
    function setIcon(v) { iconSize = clampIcon(v); }

    // Show the app names under the icons. Off: cells shrink to the icon and the name appears
    // in a small tip on hover.
    property alias showLabels: saved.labels
    // When a tile shows its ＋ and ⋯ buttons: "pause" (once the pointer has rested on it, so they do not sit on the icons
    // while you aim at one) or "click" (never on hover). Right-clicking a tile opens its menu either way.
    property alias tileButtons: saved.tileButtons
    readonly property int tileButtonsDelay: 7000 // ms: the user's choice (1.2 s and 5 s were both too quick)

    // The colours (accent, border, tile background, app background) and their opacity are one
    // system, see "colours" below.

    // how wide the space between the tiles is (px)
    property alias tileGap: saved.gap
    function setTileGap(v) { tileGap = Math.max(0, Math.min(100, Math.round(v / 2) * 2)); }
    // the room inside a tile and around its icons (0 = the icons almost touch the border), and so also
    // around the tiles, see layout.js cellPad() / padTop() and `outerMargin`
    property alias tilePadding: saved.padding
    function setTilePadding(v) { tilePadding = Math.max(0, Math.min(24, Math.round(v))); }
    // between the launcher's edge and its tiles: 12 px, or the padding when that is smaller
    readonly property real outerMargin: Math.min(12, tilePadding)
    // corner roundness of the tiles (0 = square corners, the default, like Omarchy's windows; higher = rounder)
    property alias tileRadius: saved.radius
    // The launcher's own surfaces (its card, the selection, the all-apps list, the picker, the filter pill, tips)
    // round as much as the tiles, up to 12 px: square by default, rounded together when the tiles are. The menus
    // are always square.
    readonly property real corner: Math.min(tileRadius, 12)
    // the corners of a strip button's background (and of the profile buttons): those of the button style
    function stripRadius(w) {
        return iconTheme === "circle" ? w / 2 : (iconTheme === "line-square" || iconTheme === "metro" ? 0 : w * 0.25);
    }
    function setTileRadius(v) { tileRadius = Math.max(0, Math.min(28, Math.round(v / 2) * 2)); }
    // thickness of every tile's border
    property alias tileBorderWidth: saved.borderWidth
    function setTileBorderWidth(v) { tileBorderWidth = Math.max(1, Math.min(10, Math.round(v))); }
    // "Allow all apps in search" (⚙ menu): while typing, look through every installed app instead of
    // only the apps in your tiles. The matches then replace the tiles (see SearchResults.qml).
    property alias searchAll: saved.searchAll
    // whether those results show the app names (independent of the global "Show names")
    property alias searchLabels: saved.searchLabels
    // text size of the "Filter: ..." pill shown at the top while typing
    property alias filterFontSize: saved.filterFontSize
    function setFilterFontSize(v) { filterFontSize = Math.max(12, Math.min(42, Math.round(v))); }

    // Power buttons (shut down, restart, log out): a strip along the bottom of the launcher, under
    // the tiles (⚙ menu). They never change the size of the tiles: they share the footer strip that
    // is already there for the ⚙ button.
    // Each one is switched on separately (⚙ > Buttons).
    property alias powerOffButton: saved.powerOffButton
    property alias restartButton: saved.restartButton
    property alias logoutButton: saved.logoutButton
    // "All apps" button: sits in the same strip as the power buttons. Clicking it flips the tiles over
    // to a list of every installed app, without typing anything (`allAppsOpen`); `flip` (0 = tiles,
    // 1 = all apps) drives the flip animation and is not animated while the launcher is hidden.
    property alias allAppsButton: saved.allAppsButton
    onAllAppsButtonChanged: { if (!allAppsButton) allAppsOpen = false; }
    property bool allAppsOpen: false
    // 0 = the tiles, 1 = every installed app (the button, or typing with "search all apps" on): the launcher grows
    // to the whole screen while the tiles fade out and the list fades in (see `grow` and LauncherContent.qml)
    property real flip: allAppsOpen || typedSearch ? 1 : 0
    Behavior on flip { enabled: root.opened; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    readonly property bool stripOn: allAppsButton || powerOffButton || restartButton || logoutButton || profileButtons.length > 0
    // with any button on, the strip sits on the side opposite to the edge the launcher is
    // docked to (docked to the top: below; to the bottom: above; left: on the right; right: on
    // the left; the centred card and full screen: below). It never changes the size of the
    // tiles: below, it sits in the footer strip that is already there; on the other sides the
    // docked window grows by `powerPad` px to make room for it.
    readonly property string powerSide: edge === "top" ? "bottom" : (edge === "bottom" ? "top" : (edge === "left" ? "right" : (edge === "right" ? "left" : "bottom")))
    readonly property real powerPad: stripOn && powerSide !== "bottom" ? powerButtonSize + 10 : 0
    // size of the power/all-apps buttons in that strip (⚙ menu)
    property alias powerButtonSize: saved.powerButtonSize
    function setPowerButtonSize(v) { powerButtonSize = Math.max(20, Math.min(56, Math.round(v / 2) * 2)); }
    // Look of those buttons (⚙ menu): a folder of assets/icons/themes/ with the same four images
    // (all-apps, power-off, restart, logout). "line-square" (Square line) is the default; "grid" matches the launcher's own icon.
    property alias iconTheme: saved.iconTheme
    readonly property var iconThemes: [
        { value: "grid", text: "Grid" }, { value: "pastel", text: "Pastel" }, { value: "carbon", text: "Carbon" },
        { value: "line", text: "Line" }, { value: "line-square", text: "Square line" },
        { value: "circle", text: "Circle" }, { value: "metro", text: "Metro" }
    ]
    // (an unknown saved theme is the default one here at once: the buttons are built before loadSettings()
    // puts the saved value right, and would try to load a folder that does not exist)
    // Size of both menus (⚙ > Window > "Menu size"), in % (70-160, step 5): everything in them,
    // text and controls, is scaled together (`scale` on the menu item).
    property alias menuScalePct: saved.menuScale
    readonly property real menuScale: menuScalePct / 100
    function setMenuScale(v) { menuScalePct = Math.max(70, Math.min(160, Math.round(v / 5) * 5)); }
    // The two stroke-only styles (Line, Square line) draw light strokes with no fill of their own, so
    // over a light surface (the Light look, or a light "Button background") they use the dark copy
    // of the same drawing (`line-dark`, `line-square-dark` in assets/icons/themes/).
    readonly property bool stripLight: Colors.isLight(Colors.over(rgbOf(paint("powerBg", null)), appSurface))
    function iconFor(theme, name) {
        const t = iconThemes.some(x => x.value === theme) ? theme : Config.DEFAULTS.iconTheme;
        const folder = stripLight && (t === "line" || t === "line-square") ? t + "-dark" : t;
        return Qt.resolvedUrl("assets/icons/themes/" + folder + "/" + name + ".svg");
    }
    function stripIcon(name) { return iconFor(iconTheme, name); }
    // flag: "--power-off", "--reboot" or "--logout" (kept for the button/shortcut wiring below),
    // mapped to the Omarchy session commands (the same ones its own menu uses).
    function powerAction(flag) {
        hide();
        const cmd = flag === "--power-off" ? "omarchy-system-shutdown"
                  : flag === "--reboot" ? "omarchy-system-reboot"
                  : "omarchy-system-logout";
        Quickshell.execDetached([cmd]);
    }

    //---------------------------------------------------------- colours
    readonly property string configDir: Quickshell.env("HOME") + "/.config/gona-launcher"
    // The launcher has two looks, Dark and Light (⚙ > Colors), chosen by `theme`. Each look has its own
    // version of the 8 colours to choose from (`palette`): vivid ones that stand out on a dark surface,
    // deeper ones that keep their contrast on a light one. Same order, same names in both.
    property alias theme: saved.theme // "dark" | "light" | "auto" (Omarchy's own light/dark setting)
    property alias followTheme: saved.followTheme // use the active Omarchy theme's colours (below)
    property alias trackUsage: saved.trackUsage   // count the apps launched (see "usage" below)
    property alias showProfileButtons: saved.showProfileButtons // the profiles as buttons in the strip (see profiles)
    property alias profileLabels: saved.profileLabels             // "numbers" | "letters" | "roman"
    property alias nextToBar: saved.nextToBar // a docked panel opens next to the bar button that opened it
    property alias showUsageRow: saved.showUsageRow // a row of the apps used most (or last) above the tiles
    property alias usageRowCount: saved.usageRowCount
    property alias usageOrder: saved.usageOrder   // "name" | "most_used" | "recent": order of the all-apps list and of the typed search
    // The active Omarchy theme, read from ~/.local/state/omarchy/current/theme/colors.toml when the launcher
    // starts and every time it opens (a theme switch shows on the next open): its `mode`, `accent`,
    // `background`, `red`, `blue`, ... as "#rrggbb"; {} when there is no such file.
    property var omarchyColors: ({})
    function refreshOmarchy() {
        let c = {};
        try { c = Toml.parse(readFile(Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml")); } catch (e) { c = {}; }
        const out = {};
        for (const k in c) if (typeof c[k] === "string" && (k === "mode" || /^#[0-9a-fA-F]{6}$/.test(c[k]))) out[k] = c[k];
        omarchyColors = out;
    }
    readonly property bool omarchyOk: omarchyColors.accent !== undefined && omarchyColors.background !== undefined
    readonly property string omarchyMode: omarchyColors.mode === "light" || omarchyColors.mode === "dark" ? omarchyColors.mode
                                          : (omarchyOk && Colors.isLight(Colors.parseHex(omarchyColors.background)) ? "light" : "dark")
    readonly property bool lightMode: theme === "light" || (theme === "auto" && omarchyMode === "light")
    // The theme's colours are used for "System" (accent, backgrounds) and for the 8 swatches when the
    // setting is on and the theme's light/dark matches the look in use (a dark theme's colours under
    // the Light look would be unreadable), otherwise the launcher's own fixed palettes below.
    readonly property bool following: followTheme && omarchyOk && omarchyMode === (lightMode ? "light" : "dark")
    readonly property var paletteDark: ["#ff69b4", "#f38ba8", "#fab387", "#f9e2af",
                                        "#a6e3a1", "#94e2d5", "#89b4fa", "#cba6f7"]
    readonly property var paletteLight: ["#d6338a", "#d20f39", "#e8590c", "#df8e1d",
                                         "#40a02b", "#179299", "#1e66f5", "#8839ef"]
    // following a theme: its accent first, then red, orange, yellow, green, cyan, blue, magenta (the same
    // order as the fixed ones, pink to purple), each falling back to the fixed colour if the theme lacks it
    readonly property var palette: {
        const fixed = lightMode ? paletteLight : paletteDark;
        if (!following) return fixed;
        const keys = ["accent", "red", "orange", "yellow", "green", "cyan", "blue", "magenta"];
        return keys.map((k, i) => omarchyColors[k] || fixed[i]);
    }
    readonly property var paletteNames: following ? ["Accent", "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Magenta"]
                                                  : ["Pink", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple"]

    // ---- the colour system --------------------------------------------------------------------
    // Four colour fields, each with its own opacity:
    //   accent  the app's own UI (selection, handles, drop targets)           global only
    //   border  the border of the tiles                                       global, and per tile
    //   bg      the background of the tiles                                   global, and per tile
    //   appBg   the app's background, i.e. the gaps between the tiles         global only
    // A field is stored as { v, a }, and either part may be missing:
    //   v  "system" (the built-in default of that field), "none" (transparent), a palette index
    //      0..7, or a "#rrggbb" string (any colour)
    //   a  opacity 0..100
    // Resolution, for each part on its own: the tile's own field, else the global one, else the
    // system default. So a tile can change only the colour and still follow the global opacity, and
    // ↺ (reset) deletes the whole field so it goes back to inheriting.
    // Global fields live in `colors` (config.toml), one set per look: `colorsDark` (`[colors.dark]` in the
    // file) and `colorsLight` (`[colors.light]`);
    // `colors` is the set of the look in use, and the only one the rest of the code reads. A tile keeps its own in its leaf as `cBorder` and
    // `cBg`. Older layouts stored plain values in `color` / `bg` / `tint`; those are simply ignored.
    // "system" is this launcher's own built-in look (systemHex() below); "Follow the Omarchy theme" is what reads
    // the Omarchy theme colours (architecture/colors.md).
    property alias colorsDark: saved.colors
    property alias colorsLight: saved.colorsLight
    readonly property var colors: lightMode ? colorsLight : colorsDark
    readonly property var defaultAlpha: ({ accent: 100, border: 40, bg: 100, appBg: 100, powerBg: 100, menuBg: 100 })

    // ---- text and chrome follow the surface they are drawn on -----------------------------------
    // Light text on a dark surface, dark text on a light one, measured on what the eye really sees
    // (the colour composited over the desktop the look assumes), so a custom or see-through
    // background never leaves unreadable text. Three surfaces: the launcher (`appBg`), the menus
    // (`menuBg`, the `m…` names) and each tile (`tileIsLight()`).
    readonly property color inkOnDark: "#cdd6f4"
    readonly property color inkOnDarkDim: "#a6adc8" // 5.4:1 on the menu background (the old #7f849c was 3.4:1)
    readonly property color inkOnLight: "#1e1e2e"
    readonly property color inkOnLightDim: "#5c5f77"
    readonly property var deskRgb: Colors.parseHex(following ? omarchyColors.background : (lightMode ? "#eff1f5" : "#1e1e2e")) // what shows through a see-through card
    function rgbOf(c) { return { r: c.r, g: c.g, b: c.b, a: c.a }; }
    readonly property var appSurface: Colors.over(rgbOf(bgColor), deskRgb)
    readonly property var menuSurface: Colors.over(rgbOf(paint("menuBg", null)), deskRgb)
    readonly property bool appLight: Colors.isLight(appSurface)
    readonly property bool menuLight: Colors.isLight(menuSurface)
    function inkColor(light, dimmed) { return light ? (dimmed ? inkOnLightDim : inkOnLight) : (dimmed ? inkOnDarkDim : inkOnDark); }
    function chromeColor(light) { return light ? "#ccd0da" : "#45475a"; }
    function hoverColor(light) { return light ? "#1a000000" : "#33ffffff"; }
    // a raised surface (tooltips, pills, inputs): the surface nudged toward its own text colour
    function raised(surface, light, amount) { return Qt.color(Colors.toHex(Colors.mix(surface, rgbOf(inkColor(light, false)), amount))); }

    readonly property color fg: inkColor(appLight, false)      // the launcher's text
    readonly property color dim: inkColor(appLight, true)
    readonly property color border: chromeColor(appLight)
    readonly property color hover: hoverColor(appLight)
    readonly property color popupBg: raised(appSurface, appLight, 0.12) // filter pill, tooltips, search box

    readonly property color mFg: inkColor(menuLight, false)    // the ⚙ / ⋯ menus' own text
    readonly property color mDim: inkColor(menuLight, true)
    readonly property color mBorder: chromeColor(menuLight)
    readonly property color mHover: hoverColor(menuLight)
    readonly property color mField: raised(menuSurface, menuLight, 0.09)  // text inputs
    readonly property color mPopup: raised(menuSurface, menuLight, 0.16)  // tooltips
    readonly property color mDanger: menuLight ? "#d20f39" : "#f38ba8"

    function tileKey(field) { return field === "border" ? "cBorder" : "cBg"; }
    // a stored field with only its valid parts, or undefined when it has none (colors.js)
    function cleanField(f) { return Colors.cleanField(f, palette.length); }
    // the "system" colour of a field as "#rrggbb" ("" = nothing is drawn)
    function systemHex(field) {
        if (field === "accent") return palette[0];
        if (field === "border") return hexFor("accent", pick("accent", null).v); // the accent, softly
        if (field === "appBg") return following ? omarchyColors.background : (lightMode ? "#eff1f5" : "#1e1e2e");
        if (field === "menuBg") return following ? (omarchyColors.lighter_background || omarchyColors.selection || omarchyColors.background)
                                                 : (lightMode ? "#ffffff" : "#313244"); // the ⚙/⋯ menus' own background
        return ""; // tiles have no fill of their own: the app background shows through
    }
    // any value of a field as "#rrggbb"; "" = nothing (transparent)
    function hexFor(field, v) {
        if (v === "none") return "";
        if (v === "system") return systemHex(field);
        return typeof v === "number" ? palette[v] : v;
    }
    // The effective { v, a } of a field. `tile` is a leaf (its own field wins) or null for the global one.
    function pick(field, tile) {
        const t = tile ? cleanField(tile[tileKey(field)]) : undefined;
        const g = cleanField(colors[field]);
        return {
            v: t && t.v !== undefined ? t.v : (g && g.v !== undefined ? g.v : "system"),
            a: t && t.a !== undefined ? t.a : (g && g.a !== undefined ? g.a : defaultAlpha[field])
        };
    }
    // A palette colour used as a tile background is turned into a soft tint of it, so the presets read
    // as quiet surfaces rather than solid blocks: mostly white in the Light look (a pastel), mostly
    // the dark surface in the Dark one. Any other colour (custom, or a palette colour on another
    // field) is used exactly as chosen.
    readonly property real bgTintLight: 0.16
    readonly property real bgTintDark: 0.26
    function tintOf(hex) {
        return lightMode ? Colors.mix(Colors.parseHex("#ffffff"), Colors.parseHex(hex), bgTintLight)
                         : Colors.mix(Colors.parseHex("#181825"), Colors.parseHex(hex), bgTintDark);
    }
    // The colour to draw for a field, with its opacity.
    function solidOf(field, v) {
        const hex = hexFor(field, v);
        if (hex === "") return null;
        return field === "bg" && typeof v === "number" ? Qt.color(Colors.toHex(tintOf(hex))) : Qt.color(hex);
    }
    // What a palette swatch of `field` looks like once applied in the current look (the swatches of
    // the colour picker show this, so the preview is the result and not the raw palette colour).
    function swatchFor(field, index) { return solidOf(field, index); }
    function paint(field, tile) {
        const r = pick(field, tile);
        const c = solidOf(field, r.v);
        return c ? Qt.rgba(c.r, c.g, c.b, r.a / 100) : Qt.rgba(0, 0, 0, 0);
    }
    // The surface a tile really shows: its background over the launcher's. A light one needs dark text,
    // a dark one light text; a see-through tile takes the launcher's own brightness.
    function tileSurface(tile) { return Colors.over(rgbOf(paint("bg", tile)), appSurface); }
    function tileIsLight(tile) { return Colors.isLight(tileSurface(tile)); }

    readonly property color accent: paint("accent", null)      // selection, handles, drop targets
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, accent.a * 0.2)   // selected-cell fill
    readonly property color accentGuide: Qt.rgba(accent.r, accent.g, accent.b, accent.a * 0.4)  // resize guides
    // the launcher card's background
    readonly property color bgColor: paint("appBg", null)
    // same colour, but never see-through: the app picker uses this so it is readable even when the
    // app background is transparent (it covers the whole card, not just the gaps between tiles)
    readonly property color solidBg: Qt.rgba(appSurface.r, appSurface.g, appSurface.b, 1)

    function setColor(field, patch) {
        const c = Object.assign({}, colors);
        const n = Colors.patchField(c[field], patch, palette.length); // null resets (deletes) the field
        if (n === undefined) delete c[field]; else c[field] = n;
        if (lightMode) colorsLight = c; else colorsDark = c;
    }
    function setTheme(name) { theme = name === "light" || name === "auto" ? name : "dark"; }
    function setTileColor(path, field, patch) {
        const t = clone();
        const leaf = nodeAt(t, path);
        const n = Colors.patchField(leaf[tileKey(field)], patch, palette.length);
        if (n === undefined) delete leaf[tileKey(field)]; else leaf[tileKey(field)] = n;
        commit(t);
    }

    //---------------------------------------------------------- storage
    Process { command: ["mkdir", "-p", root.configDir, root.stateDir]; running: true }
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/gona-launcher"

    // Everything the launcher remembers, settings and tiles, is one file: config.toml (toml.js reads and
    // writes the text, config.js says which setting goes where). It is read once at start
    // (`Component.onCompleted` below) and written, 0.4 s after the last change, by saveNow().
    // First run after the change from two JSON files: window.json and layout.json are read once and
    // config.toml is written from them (they are left where they are, untouched).
    // The file in use: config.toml for the default profile, or profiles/<name>.toml (see "profiles" below).
    property string activeProfile: ""
    readonly property string profilesDir: configDir + "/profiles"
    function profilePath(name) { return name === "" ? configDir + "/config.toml" : profilesDir + "/" + name + ".toml"; }
    readonly property string configPath: profilePath(activeProfile)
    // watched: a config.toml edited by hand (or swapped in by another tool) while the launcher runs is read
    // again (see configEditedOutside()); the launcher's own writes are told apart by their text and time
    FileView {
        id: configFile
        path: root.configPath
        blockLoading: true
        watchChanges: true
        printErrors: false // a new profile's file is written a moment after the path changes to it
        onFileChanged: reload() // text() is stale inside this signal, so the new text arrives through onLoaded
        onLoaded: root.configEditedOutside(text())
    }
    property string lastWritten: ""
    property double lastWriteTime: 0
    FileView { id: backupFile; path: ""; watchChanges: false } // config.toml.bak, written by an import
    // The text of any file ("" when there is none). A FileView blocks until it has loaded only on its
    // first path, changing the path later hands back the old file's text, so each read gets a new one.
    function readFile(path) {
        const f = Qt.createQmlObject("import Quickshell.Io; FileView { blockLoading: true; watchChanges: false; printErrors: false; path: "
                                     + JSON.stringify(path) + " }", root, "readFile");
        let t = "";
        try { t = f.text(); } catch (e) { t = ""; }
        f.destroy();
        return t;
    }
    property bool configLoaded: false // changes made while loading are not written back

    // The settings, held in memory through `saved`: one property per setting, under its short name (the
    // one config.js maps to the file). The root properties are aliases of these (`iconSize` is
    // `saved.icon`), so a new setting takes a property here, its alias, a line in config.js (`DEFAULTS`
    // and `MAP`), and a line in loadSettings() when not every value of its type is valid. This FileView
    // has no file: it is only there so any change fires adapterUpdated, which schedules the save.
    FileView {
        id: sizeStore
        path: ""
        onAdapterUpdated: { if (root.configLoaded) saveSize.restart(); }
        adapter: JsonAdapter {
            id: saved
            property int width: 900
            property int height: 620
            property int icon: 48
            property bool labels: true
            property string tileButtons: "pause"
            property int gap: 8
            property int padding: 14
            property int radius: 0
            property int borderWidth: 2
            property bool searchAll: false
            property bool searchLabels: true
            property int filterFontSize: 14
            property bool powerOffButton: false
            property bool restartButton: false
            property bool logoutButton: false
            property bool allAppsButton: false
            property int powerButtonSize: 34
            property string iconTheme: "line-square"
            property int menuScale: 100
            property var colors: ({}) // the Dark look's (the key predates the two looks)
            property var colorsLight: ({})
            property string theme: "dark"
            property bool followTheme: true
            property bool trackUsage: true
            property string usageOrder: "most_used"
            property bool showUsageRow: false
            property bool nextToBar: false
            property bool showProfileButtons: false
            property string profileLabels: "numbers"
            property int usageRowCount: 6
            property var keys: ({})
            property string edge: ""
            property var panels: ({}) // loadSettings() fills it from defaultPanels
            property int offset: 12
            property int speed: 110
            property string fullFrom: "top"
            property string effect: "classic"
            property int effectMs: 700
            property bool closeAnim: true
            property bool reduceMotion: false
        }
    }
    Timer { id: saveSize; interval: 400; onTriggered: root.saveNow() }

    // ---- reading and writing config.toml -----------------------------------------------------
    // the settings under their short names, as plain values
    function settingsSnapshot() {
        const o = {};
        for (const n of Config.NAMES) o[n] = JSON.parse(JSON.stringify(saved[n]));
        return o;
    }
    function configText() { return Toml.stringify(Config.toConfig(settingsSnapshot(), layout), Config.COMMENTS); }
    function saveNow() {
        saveSize.stop();
        lastWritten = configText();
        lastWriteTime = Date.now();
        configFile.setText(lastWritten);
    }
    // config.toml changed on disk while the launcher was running: take it in, unless it is our own write
    // (same text, or within a second of it) or not valid TOML (the message is shown in ⚙ > Profiles and
    // the settings stay as they are). The file is not rewritten from what was read, so a person's comments
    // and layout stay until the launcher next saves a change of its own.
    function configEditedOutside(text) {
        if (!configLoaded || text.trim() === "" || text === lastWritten || Date.now() - lastWriteTime < 1000) return;
        configLoaded = false; // what applyConfigText() sets must not schedule a save
        saveSize.stop();
        const r = applyConfigText(text);
        configLoaded = true;
        if (!r.ok) transferResult("config.toml was edited but is not valid TOML (" + r.message + "); keeping the current settings", true);
        else transferResult("config.toml was edited: reloaded" + (r.problems.length ? " (" + r.problems.length + " skipped: " + r.problems[0] + ")" : ""), r.problems.length > 0);
    }
    function resetAllSettings() { for (const n of Config.NAMES) saved[n] = JSON.parse(JSON.stringify(Config.DEFAULTS[n])); }
    // Puts the settings and tiles of a config.toml text in place of the current ones (what the file
    // does not say goes back to its default; missing tiles keep the ones there are). Nothing changes
    // when the text is not valid TOML. { ok, message, problems } (problems: values skipped).
    function applyConfigText(text) {
        let cfg;
        try { cfg = Toml.parse(text); } catch (e) { return { ok: false, message: e.message, problems: [] }; }
        const r = Config.fromConfig(cfg);
        resetAllSettings();
        for (const n in r.settings) saved[n] = r.settings[n];
        if (r.layout) { layout = r.layout; clearHistory(); }
        loadSettings();
        return { ok: true, message: "", problems: r.problems };
    }
    // the two JSON files this launcher used before config.toml; true when there was anything to read
    function migrateLegacy() {
        let found = false;
        try {
            const d = JSON.parse(readFile(configDir + "/window.json"));
            if (d && typeof d === "object") {
                for (const n of Config.NAMES) if (d[n] !== undefined) saved[n] = d[n];
                const le = Config.legacyEffect(d.fullAnim, d.edge); // full screen "meet" etc. became effects of every mode
                if (le !== undefined && d.effect === undefined) saved.effect = le;
                // the single "power buttons" switch of the first versions became one switch per button
                if (d.powerButtons === true) { saved.powerOffButton = true; saved.restartButton = true; saved.logoutButton = true; }
                found = true;
            }
        } catch (e) { /* no such file, or not JSON */ }
        try {
            const t = Config.cleanLayout(JSON.parse(readFile(configDir + "/layout.json")));
            if (t) { layout = t; found = true; }
        } catch (e) { /* likewise */ }
        return found;
    }

    // ---- ⚙ > Profiles > Configuration file: export and import ---------------------------------
    property string transferPath: "~/gona-launcher-config.toml" // what the field there shows
    property string transferMessage: ""
    property bool transferFailed: false
    function transferResult(message, failed) { transferMessage = message; transferFailed = failed; }
    function expandPath(p) {
        const t = p.trim();
        const home = Quickshell.env("HOME");
        return t === "~" ? home : (t.startsWith("~/") ? home + t.slice(1) : t);
    }
    property string exportTarget: ""
    Process {
        id: exportProc
        onExited: code => root.transferResult(code === 0 ? "Exported to " + root.exportTarget : "Could not write " + root.exportTarget, code !== 0)
    }
    Timer { // gives the write of config.toml (saveNow) a moment before it is copied
        id: exportTimer
        interval: 350
        onTriggered: {
            exportProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cp -f \"$1\" \"$2\"", "sh", root.configPath, root.exportTarget];
            exportProc.running = true;
        }
    }
    function exportConfig(path) {
        const dst = expandPath(path);
        if (dst === "") { transferResult("Type the file to export to.", true); return; }
        if (dst === configPath) { transferResult("That is the file the launcher already uses.", true); return; }
        exportTarget = dst;
        saveNow();
        exportTimer.restart();
    }
    function importConfig(path) {
        const src = expandPath(path);
        if (src === "") { transferResult("Type the file to import.", true); return; }
        if (src === configPath) { transferResult("That is the file the launcher already uses.", true); return; }
        const text = readFile(src);
        if (text.trim() === "") { transferResult("Cannot read " + src, true); return; }
        try { Toml.parse(text); } catch (e) { transferResult("Not imported: " + e.message, true); return; }
        // the current settings are kept next to config.toml, in case the import was a mistake
        // (only once the file is known to be TOML, so a refused import leaves the last backup alone)
        backupFile.path = configPath + ".bak";
        backupFile.setText(configText());
        const r = applyConfigText(text);
        saveNow();
        transferResult("Imported " + src + (r.problems.length ? " (" + r.problems.length + " skipped: " + r.problems[0] + ")" : "")
                       + ". The previous settings are in config.toml.bak", false);
    }

    // ---- defaults, for the ↺ of every slider and "Reset this tab" (⚙ menu) -----------------------
    // The value each setting starts with, under its short name (config.js, the same as the adapter above).
    readonly property var defaults: Config.DEFAULTS
    function isDefault(key) { return saved[key] === defaults[key]; }
    function resetSetting(key) { saved[key] = defaults[key]; }
    // what each tab of the ⚙ menu puts back to how it started (the colours of the look in use only)
    function resetTab(name) {
        const keys = {
            tiles: ["icon", "labels", "gap", "padding", "radius", "borderWidth", "tileButtons"],
            window: ["edge", "offset", "nextToBar"],
            effects: ["effect", "effectMs", "closeAnim", "reduceMotion", "speed", "fullFrom"],
            search: ["searchAll", "searchLabels", "filterFontSize"],
            buttons: ["allAppsButton", "powerOffButton", "restartButton", "logoutButton", "showProfileButtons", "profileLabels", "powerButtonSize", "iconTheme"],
            menu: ["menuScale"],
            search: ["searchAll", "searchLabels", "filterFontSize", "trackUsage", "usageOrder", "showUsageRow", "usageRowCount"]
        }[name] || [];
        for (const k of keys) resetSetting(k);
        if (name === "tiles") resizeMode = false;
        if (name === "window") loadPanels({});
        if (name === "colors") { if (lightMode) colorsLight = ({}); else colorsDark = ({}); resetSetting("followTheme"); }
        if (name === "buttons") setColor("powerBg", null);
        if (name === "menu") setColor("menuBg", null);
        if (name === "keys") { resetAllKeys(); if (superAvailable) setSuperMode("tiles"); }
    }

    // Puts every value of `saved` that is out of range or unknown back to a valid one (whatever put
    // it there: config.toml, an import, the JSON files of an older version). Old keys (colour
    // `opacity`, `accent`, `viewOnPanel`/`anchorPos`/`anchorThickness` from the Cinnamon panel applet,
    // ...) are ignored, not migrated.
    function loadSettings() {
        if (!(winW > 100 && winH > 100)) { winW = 900; winH = 620; }
        setIcon(iconSize || 48);
        setFilterFontSize(filterFontSize);
        setPowerButtonSize(powerButtonSize);
        setTileGap(tileGap); // 0 is a valid gap, and radius, and padding
        setTilePadding(tilePadding);
        setTileRadius(tileRadius);
        setTileBorderWidth(tileBorderWidth);
        // clamped, not rounded like the slider does: the default (110) is off its 50 ms steps
        slideSpeed = Math.max(0, Math.min(2000, slideSpeed)); // 0 is valid (instant)
        effectMs = Math.max(0, Math.min(2000, effectMs));
        if (effect !== "classic" && !Fx.NAMES.includes(effect)) effect = "classic";
        sharedOffset = Math.max(0, Math.min(200, Math.round(sharedOffset / 4) * 4));
        if (!["", "top", "bottom", "left", "right", "full"].includes(edge)) edge = "";
        if (!["top", "bottom", "left", "right"].includes(fullFrom)) fullFrom = "top";
        if (!iconThemes.some(t => t.value === iconTheme)) iconTheme = Config.DEFAULTS.iconTheme;
        setMenuScale(menuScalePct || 100);
        // the adapter hands JSON arrays over as Qt lists (Array.isArray() is false for them), so
        // pass plain JS values on
        loadPanels(JSON.parse(JSON.stringify(panels || {})));
        const k = {}; // only known actions, with a usable combination or "" (disabled)
        for (const a of keyActions) {
            const v = keys && typeof keys === "object" ? keys[a.name] : undefined;
            if (v === "" || KeyCombo.validCombo(v)) k[a.name] = v;
        }
        keys = k;
        if (theme !== "dark" && theme !== "light" && theme !== "auto") theme = "dark";
        usageRowCount = Math.max(3, Math.min(10, Math.round(usageRowCount)));
        if (profileLabels !== "numbers" && profileLabels !== "letters" && profileLabels !== "roman") profileLabels = "numbers";
        if (tileButtons !== "pause" && tileButtons !== "click") tileButtons = "pause";
        if (usageOrder !== "name" && usageOrder !== "most_used" && usageOrder !== "recent") usageOrder = "most_used";
        const clean = set => { // only valid fields
            const c = {};
            for (const f of ["accent", "border", "bg", "appBg", "powerBg", "menuBg"]) {
                const v = set && typeof set === "object" ? cleanField(set[f]) : undefined;
                if (v !== undefined) c[f] = v;
            }
            return c;
        };
        colorsDark = clean(colorsDark);
        colorsLight = clean(colorsLight);
    }

    Component.onCompleted: {
        root.activeProfile = root.savedProfile();
        const text = root.readFile(root.configPath);
        if (text.trim() !== "") {
            const r = root.applyConfigText(text);
            if (!r.ok) {
                // keep what was there: the next change rewrites config.toml, and this is a file somebody edited
                console.warn("gona-launcher: config.toml was not read (" + r.message + "); using the defaults. A copy is in config.toml.broken");
                Quickshell.execDetached(["cp", "-f", root.configPath, root.configPath + ".broken"]);
                root.loadSettings();
            } else if (r.problems.length > 0) {
                console.warn("gona-launcher: config.toml: " + r.problems.join("; "));
            }
            root.configLoaded = true;
        } else {
            const migrated = root.migrateLegacy();
            root.loadSettings();
            root.configLoaded = true;
            if (migrated) root.saveNow();
            else { root.welcomeFirstRun = true; root.welcomeOpen = true; } // the first start: choose a preset
        }
        root.lastWritten = text; // the watcher reads the file once more after it is opened: not an edit
        root.lastWriteTime = Date.now();
        root.refreshOmarchy();
        root.loadUsage();
        root.refreshProfiles();
        root.refreshSuperKey();
    }

    //---------------------------------------------------------- tile properties
    // the tile (leaf) at `path`, or {} when there is no such tile any more
    function leafAt(path) { return Tree.leafAt(layout, path); }
    // The tile's title (shown along its top edge) and where it sits there: "left", "center" or
    // "right". Empty text removes the title; "left" is the default and is not stored.
    function setTileTitle(path, text) {
        const t = clone();
        const leaf = nodeAt(t, path);
        if (text === "") delete leaf.title; else leaf.title = text;
        commit(t);
    }
    function setTileTitleAlign(path, align) {
        const t = clone();
        const leaf = nodeAt(t, path);
        if (align === "left") delete leaf.titleAlign; else leaf.titleAlign = align;
        commit(t);
    }
    // The title's font: `key` is "titleFont" (a family; "" = the default one), "titleBold" (on by
    // default) or "titleItalic" (off by default). A value equal to the default is not stored.
    function setTileTitleStyle(path, key, value) {
        const t = clone();
        const leaf = nodeAt(t, path);
        const isDefault = key === "titleBold" ? value === true : (key === "titleItalic" ? value === false : value === "");
        if (isDefault) delete leaf[key]; else leaf[key] = value;
        commit(t);
    }
    // per-tile alignment flags: "centerH" / "centerV" (the icons are centred in the tile)
    function setTileFlag(path, flag, on) {
        const t = clone();
        const leaf = nodeAt(t, path);
        if (on) leaf[flag] = true; else delete leaf[flag];
        commit(t);
    }
    // Per-tile icon size: a leaf may carry its own `icon`; otherwise it uses the default size.
    property var hoverPath: null // tile under the pointer, or null
    function tileIcon(path) { return nodeAt(layout, path).icon || iconSize; }
    function setTileIcon(path, v) {
        const t = clone();
        nodeAt(t, path).icon = clampIcon(v);
        commit(t);
    }
    function clearTileIcon(path) {
        const t = clone();
        delete nodeAt(t, path).icon;
        commit(t);
    }
    // Ctrl+wheel / Ctrl +/-: the hovered tile if there is one, else the default size
    function adjustIcon(delta) {
        if (hoverPath !== null) setTileIcon(hoverPath, tileIcon(hoverPath) + delta);
        else setIcon(iconSize + delta);
    }
    function resetIcon() {
        if (hoverPath !== null) clearTileIcon(hoverPath);
        else setIcon(48);
    }
    // size of one app cell for a given icon size (the same formula the cells themselves use)
    // `labels` (optional) overrides the global "Show names", for the search results
    function cellWidth(size, labels) { return Tree.cellWidth(size, labels === undefined ? showLabels : labels, tilePadding); }
    function cellHeight(size, labels) { return Tree.cellHeight(size, labels === undefined ? showLabels : labels, tilePadding); }
    // a tile's padding at the top (room for its title, see layout.js padTop())
    function tilePadTop(spec) { return Tree.padTop(spec, tilePadding); }
    readonly property real cellPad: Tree.cellPad(tilePadding) // around an icon, without names
    // "Launch all" (per-tile), shown as a regular cell among the apps instead of the small corner
    // button: 1 while that takes up a cell's worth of space, so the grid and the tile's minimum
    // size account for it, else 0.
    function launchAllExtra(spec) { return Tree.launchAllExtra(spec); }
    // A value that can never be a real desktop entry id, standing in for "Launch all" inside a
    // tile's icon grid (see displayIds()); it is never written to `ids` itself.
    readonly property string launchAllMarker: "\u0000launchAll"
    // `spec.ids` with the marker spliced in at `launchAllIndex` (how many real ids come before it,
    // clamped; default 0 = first), when "Launch all" is shown as a regular icon. What Node.qml's
    // grid is built from.
    function displayIds(spec) { return Tree.displayIds(spec, launchAllMarker); }

    //---------------------------------------------------------- minimum size of a tile
    // A tile is never smaller than what its icons need (Node.qml lays them out in a wrapping grid
    // inside the tile's padding), so a new icon never ends up hidden behind the scroll. The minimum
    // is worked out here, and used to keep every divider from squeezing a tile below it (effRatio),
    // and as the launcher card's minimum size, see minWinH.
    readonly property real cellGap: 4                        // between the cells of a tile
    // what the minimum size of a tile depends on (see layout.js, leafMinH and below)
    // `count`: a tile takes room only for its installed apps (a preset lists alternatives), whatever the filter
    readonly property var sizing: ({ icon: iconSize, labels: showLabels, gap: tileGap,
                                     cellGap: cellGap, pad: tilePadding, count: installedCountIn })
    // The divider position of split `n` (in a box w x h) that respects both sides' minimum, as
    // near to `ratio` as possible (Node.qml, for display and while dragging).
    function effRatio(n, w, h, ratio) { return Tree.effRatio(n, w, h, ratio, sizing); }
    // The card is never smaller than its tiles need (its minimumSize), so it grows as icons are
    // added instead of hiding them; the resize grip only ever makes it bigger than this.
    // 2 × outerMargin = the margins of LauncherContent.qml; the footer strip (LauncherContent's footerH) is 0
    // unless the power/all-apps row is docked at the bottom, matching that same formula here.
    readonly property real footerH: (stripOn && powerSide === "bottom") ? powerButtonSize + 8 : 0
    readonly property real minWinW: Math.ceil(Tree.floorW(layout, sizing) + 2 * outerMargin)
    readonly property real minWinH: Math.ceil(Tree.minH(layout, winW - 2 * outerMargin, sizing) + 2 * outerMargin + footerH + powerPad + usageRowH)
    function screenLimit(dim) {
        const sc = targetScreen;
        return sc ? sc[dim] - 80 : 1000;
    }
    // how many of these app ids are currently shown (see shownIds)
    // Icons shrink to fit their tile (never below this) instead of being cut off by its edge (Node.qml)
    readonly property int minIcon: 24
    function fitIcon(base, n, w, h) { return Tree.fitIcon(base, n, w, h, showLabels, tilePadding, cellGap, minIcon); }
    function installedCountIn(ids) {
        DesktopEntries.applications.values; // re-evaluate once the desktop entries have loaded
        return ids.filter(id => DesktopEntries.byId(id)).length;
    }
    function shownCountIn(ids) {
        DesktopEntries.applications.values; // re-evaluate once the desktop entries have loaded
        return shownIds(ids).length;
    }

    //---------------------------------------------------------- tree operations
    function clone() { return JSON.parse(JSON.stringify(root.layout)); }
    function nodeAt(tree, path) { return Tree.nodeAt(tree, path); }
    function walkLeaves(n, fn) { Tree.walkLeaves(n, fn); }
    // Undo / redo of the tile edits (Ctrl+Z, Ctrl+Shift+Z, and the buttons in ⚙ > Tiles): every commit()
    // that changes the tree keeps the tree it replaced, up to 50 steps; a divider drag is one step (it is
    // committed on release). The stacks hold JSON text and are gone when the launcher restarts or a
    // configuration is imported.
    property var undoStack: []
    property var redoStack: []
    readonly property int undoSteps: undoStack.length
    readonly property int redoSteps: redoStack.length
    function commit(tree) {
        const before = JSON.stringify(layout);
        if (before !== JSON.stringify(tree)) {
            undoStack = undoStack.concat([before]).slice(-50);
            redoStack = [];
        }
        root.layout = tree;
        saveSize.restart();
    }
    function clearHistory() { undoStack = []; redoStack = []; }
    function stepHistory(fromUndo) {
        const from = fromUndo ? undoStack : redoStack;
        if (from.length === 0) return false;
        const target = from[from.length - 1];
        const other = (fromUndo ? redoStack : undoStack).concat([JSON.stringify(layout)]);
        if (fromUndo) { undoStack = from.slice(0, -1); redoStack = other; }
        else { redoStack = from.slice(0, -1); undoStack = other; }
        root.layout = JSON.parse(target);
        saveSize.restart();
        return true;
    }
    function undoLayout() { return stepHistory(true); }
    function redoLayout() { return stepHistory(false); }

    // Put app `id` in the tile at `path`, before `beforeId` (or last). An app lives in one tile only.
    // With `after`, it goes after `beforeId` instead of before it.
    function moveApp(id, path, beforeId, after) {
        Qt.callLater(() => { // let the drag finish before the delegates are rebuilt
            const t = clone();
            walkLeaves(t, leaf => { leaf.ids = leaf.ids.filter(i => i !== id); });
            const target = nodeAt(t, path);
            let pos = beforeId ? target.ids.indexOf(beforeId) : -1;
            if (pos >= 0 && after) pos++;
            if (pos >= 0) target.ids.splice(pos, 0, id); else target.ids.push(id);
            commit(t);
        });
    }
    // Dragging the "Launch all" icon to just before/after `beforeId` ("" = the end), like moveApp
    // but for the marker: it is never in `ids`, so its place is `launchAllIndex` instead.
    function moveLaunchAll(path, beforeId, after) {
        Qt.callLater(() => {
            const t = clone();
            const leaf = nodeAt(t, path);
            let pos = beforeId ? leaf.ids.indexOf(beforeId) : leaf.ids.length;
            if (pos < 0) pos = leaf.ids.length;
            if (after) pos++;
            leaf.launchAllIndex = Math.max(0, Math.min(pos, leaf.ids.length));
            commit(t);
        });
    }
    // Dragging a real app onto the "Launch all" icon: it lands right there (moveApp cannot target
    // the icon directly since it is not a real id). `after` only decides which side of it the icon
    // ends up on, since the icon itself takes no slot in `ids`.
    function moveAppToLaunchAll(id, path, after) {
        Qt.callLater(() => {
            const t = clone();
            walkLeaves(t, leaf => { leaf.ids = leaf.ids.filter(i => i !== id); });
            const target = nodeAt(t, path);
            const k = Math.max(0, Math.min(target.launchAllIndex || 0, target.ids.length));
            target.ids.splice(k, 0, id);
            if (!after) target.launchAllIndex = k + 1; // dropped before the icon: it shifts past the app
            commit(t);
        });
    }
    // Add several apps at once (from the picker) to the end of the tile at `path`.
    function addApps(path, ids) {
        const t = clone();
        walkLeaves(t, leaf => { leaf.ids = leaf.ids.filter(i => !ids.includes(i)); });
        nodeAt(t, path).ids.push(...ids);
        commit(t);
    }
    function removeApp(id) {
        const t = clone();
        walkLeaves(t, leaf => { leaf.ids = leaf.ids.filter(i => i !== id); });
        commit(t);
    }
    // dir "h" = new tile to the right, "v" = new tile below
    function split(path, dir) {
        const t = clone();
        Tree.splitAt(t, path, dir);
        commit(t);
    }
    // Close a tile: its sibling takes the whole space. The last tile is only emptied.
    function closeNode(path) {
        const t = clone();
        Tree.closeAt(t, path);
        commit(t);
    }
    //---------------------------------------------------------- type-to-filter
    // Typing letters or digits in the launcher filters the apps in every tile; the rest are hidden.
    // Esc clears it, Enter launches the first match. It resets once the launcher is hidden.
    property string filterText: ""

    function matchesFilter(entry) {
        if (filterText === "") return true;
        if (!entry) return false;
        return ((entry.name || "") + " " + (entry.genericName || "")).toLowerCase().includes(filterText.toLowerCase());
    }
    // the search covers every installed app (see `searchAll`) and not only the apps in your tiles
    // typing with "Allow all apps in search" on: the matches replace the tiles at once
    readonly property bool typedSearch: searchAll && filterText !== ""
    // the list of every installed app (matching the filter) is what the launcher works on while it is
    // typed, while the "all apps" view is open, and while it flips back
    readonly property bool searchingAll: typedSearch || allAppsOpen || flip > 0
    property var searchCells: ({}) // app id -> its cell in the search results
    // ids of every installed app that matches the filter: by name, or (⚙ > Search) the most launched or the
    // most recently launched first, by name among equals
    readonly property var searchResults: {
        if (!searchingAll) return [];
        const list = DesktopEntries.applications.values.filter(e => !e.noDisplay && matchesFilter(e));
        list.sort((a, b) => {
            if (usageOrder === "most_used") { const d = usageOf(b.id).n - usageOf(a.id).n; if (d !== 0) return d; }
            else if (usageOrder === "recent") { const d = usageOf(b.id).last - usageOf(a.id).last; if (d !== 0) return d; }
            return a.name.localeCompare(b.name);
        });
        return list.map(e => e.id);
    }
    // the results are computed after the filter text changes: select the first one only then
    onSearchResultsChanged: { if (searchingAll) selectedId = searchResults.length ? searchResults[0] : ""; }
    // the first app that matches, in tile order (left to right, top to bottom)
    function firstMatch() {
        const ids = orderedVisibleIds();
        return ids.length ? DesktopEntries.byId(ids[0]) : null;
    }
    //---------------------------------------------------------- keyboard shortcuts
    // Actions with a key combination the user can change (⚙ > Keys). A combination is text such as
    // "Ctrl+Shift+P": modifiers in the order Ctrl, Alt, Shift, Meta, then the key (letter, digit, F1..F12,
    // Comma, Period, Slash, arrows, PgUp, PgDown, Home, End, Tab, Space). It must contain Ctrl or Alt
    // (F-keys may stand alone), because plain letters and digits start the type-to-filter. `keys` holds
    // only what the user changed: a combination, or "" for "disabled". Fixed keys, not listed here:
    // arrows, Tab, Enter, Space, Esc, Ctrl +/-/0 (zoom) and Alt+1..9 (select the nth app of the tile).
    readonly property var keyActions: [
        { name: "allApps",  label: "Show all apps",               def: "Ctrl+A" },
        { name: "options",  label: "Open / close ⚙ menu",           def: "Ctrl+Comma" },
        { name: "theme",    label: "Switch Dark / Light",           def: "Ctrl+T" },
        { name: "nextTab",  label: "Next menu tab",                 def: "Ctrl+PgDown" },
        { name: "prevTab",  label: "Previous menu tab",             def: "Ctrl+PgUp" },
        { name: "nextTile", label: "Next tile",                    def: "Ctrl+Tab" },
        { name: "prevTile", label: "Previous tile",                def: "Ctrl+Shift+Tab" },
        { name: "powerOff", label: "Shut down",                    def: "Ctrl+Shift+P" },
        { name: "reboot",   label: "Restart",                      def: "Ctrl+Shift+R" },
        { name: "logout",   label: "Log out",                      def: "Ctrl+Shift+L" },
        { name: "nextProfile", label: "Next profile",              def: "Ctrl+P" },
        { name: "undo",     label: "Undo tile change",             def: "Ctrl+Z" },
        { name: "redo",     label: "Redo tile change",             def: "Ctrl+Shift+Z" }
    ]
    property alias keys: saved.keys
    function keyAction(name) { return keyActions.find(a => a.name === name); }
    function comboFor(name) {
        const a = keyAction(name);
        if (!a) return "";
        return typeof keys[name] === "string" ? keys[name] : a.def;
    }
    function actionFor(combo) {
        if (combo === "") return "";
        const a = keyActions.find(x => comboFor(x.name) === combo);
        return a ? a.name : "";
    }
    // Changing a shortcut: `captureAction` is the action waiting for its new combination (⚙ > Keys);
    // `captureMessage` says why the last try was refused.
    // asks whichever menu is open to take the keyboard focus back (a text field that lets go of it
    // would otherwise leave the focus on the window, and Esc could no longer close the menu)
    signal menuFocusRequested()
    property string captureAction: ""
    property string captureMessage: ""
    function startCapture(name) { captureAction = name; captureMessage = ""; }
    function setKey(name, combo) {
        const k = Object.assign({}, keys);
        if (combo === keyAction(name).def) delete k[name]; else k[name] = combo;
        keys = k;
    }
    function resetKey(name) { const k = Object.assign({}, keys); delete k[name]; keys = k; }
    function resetAllKeys() { keys = ({}); captureAction = ""; captureMessage = ""; }
    // a key event while a new combination is awaited: Esc cancels, Backspace/Delete disables the action
    function captureKey(event) {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Shift
            || event.key === Qt.Key_Meta || event.key === Qt.Key_AltGr) return; // wait for the real key
        if (event.key === Qt.Key_Escape) { captureAction = ""; captureMessage = ""; return; }
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) { setKey(captureAction, ""); captureAction = ""; captureMessage = ""; return; }
        const combo = KeyCombo.comboOf(event);
        if (combo === "") { captureMessage = "That key cannot be used."; return; }
        const problem = KeyCombo.comboProblem(combo);
        if (problem !== "") { captureMessage = problem; return; }
        const other = actionFor(combo);
        if (other !== "" && other !== captureAction) { captureMessage = "Already used by \"" + keyAction(other).label + "\"."; return; }
        setKey(captureAction, combo);
        captureAction = "";
        captureMessage = "";
    }
    // A key press in the launcher or a menu: runs the action it belongs to. True when it was used.
    function handleKey(event) {
        if (pickingPath !== null || captureAction !== "") return false;
        if (event.modifiers === Qt.AltModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            selectNth(event.key - Qt.Key_0);
            return true;
        }
        const act = actionFor(KeyCombo.comboOf(event));
        if (act === "") return false;
        runAction(act);
        return true;
    }
    function runAction(name) {
        switch (name) {
        case "allApps": allAppsOpen = !allAppsOpen; break;
        case "options": toggleOptions(); break;
        case "theme": setTheme(lightMode ? "dark" : "light"); break;
        case "nextTab": stepTab(1); break;
        case "prevTab": stepTab(-1); break;
        case "nextTile": selectTile(1); break;
        case "prevTile": selectTile(-1); break;
        case "powerOff": powerAction("--power-off"); break;
        case "reboot": powerAction("--reboot"); break;
        case "logout": powerAction("--logout"); break;
        case "nextProfile": cycleProfile(1); break;
        case "undo": undoLayout(); break;
        case "redo": redoLayout(); break;
        }
    }
    // next / previous tab of whichever menu is open
    function stepTab(delta) {
        const m = optionsOpen ? floatingMenu : (tileMenuPath !== null ? tileMenu : null);
        if (m) m.tab = (m.tab + delta + m.tabCount) % m.tabCount;
    }
    // the apps among `ids` that are shown: installed, and matching the type-to-filter
    function shownIds(ids) {
        return ids.filter(id => { const e = DesktopEntries.byId(id); return e && matchesFilter(e); });
    }
    // the apps that are shown, grouped by tile (a tile with none shown is left out), in tile order
    function visibleGroups() {
        const groups = [];
        walkLeaves(layout, leaf => {
            const ids = shownIds(leaf.ids);
            if (ids.length) groups.push(ids);
        });
        return groups;
    }
    // jump to the first app of the next / previous tile (nothing in the all-apps list, which has no tiles)
    function selectTile(delta) {
        if (searchingAll) return;
        const groups = visibleGroups();
        if (!groups.length) return;
        let i = groups.findIndex(g => g.includes(selectedId));
        i = i < 0 ? (delta > 0 ? 0 : groups.length - 1) : (i + delta + groups.length) % groups.length;
        selectedId = groups[i][0];
    }
    // Alt+1..9: the nth app of the tile that holds the selection (the first tile when nothing is selected)
    function selectNth(n) {
        if (searchingAll) return;
        const groups = visibleGroups();
        if (!groups.length) return;
        const g = groups.find(x => x.includes(selectedId)) || groups[0];
        if (n <= g.length) selectedId = g[n - 1];
    }

    //---------------------------------------------------------- keyboard selection
    // One app can be selected (highlighted in pink). Arrow keys move the selection to the nearest
    // app in that direction (across tiles too), Tab / Shift+Tab step through them in tile order,
    // Enter or Space launches it. While filtering, the first match is selected automatically.
    property string selectedId: ""
    property var cellItems: ({}) // app id -> its on-screen cell, registered by the cells themselves

    onFilterTextChanged: {
        if (filterText === "") return;
        const ids = orderedVisibleIds();
        selectedId = ids.length ? ids[0] : "";
    }

    // ids of the apps currently shown (they match the filter), in tile order
    function orderedVisibleIds() {
        return searchingAll ? searchResults : [].concat(...visibleGroups());
    }
    // Tab / Shift+Tab: next or previous app, wrapping around
    function selectStep(delta) {
        const ids = orderedVisibleIds();
        if (!ids.length) return;
        let i = ids.indexOf(selectedId);
        i = i < 0 ? (delta > 0 ? 0 : ids.length - 1) : (i + delta + ids.length) % ids.length;
        selectedId = ids[i];
    }
    // Arrows: the nearest app in the direction (dx, dy), each -1, 0 or 1. Distance counts more
    // sideways than forwards, so it prefers staying in line with where you are.
    function selectDir(dx, dy) {
        const ids = orderedVisibleIds();
        if (!ids.length) return;
        const cells = searchingAll ? searchCells : cellItems;
        const here = cells[selectedId];
        if (!here || ids.indexOf(selectedId) < 0) { selectedId = ids[0]; return; }
        const centre = it => it.mapToItem(null, it.width / 2, it.height / 2);
        const c = centre(here);
        let best = "", bestScore = Infinity;
        for (const id of ids) {
            const it = cells[id];
            if (id === selectedId || !it) continue;
            const p = centre(it);
            const along = (p.x - c.x) * dx + (p.y - c.y) * dy;      // progress in the wanted direction
            const across = Math.abs((p.x - c.x) * dy) + Math.abs((p.y - c.y) * dx);
            if (along < 4) continue;                                  // not really in that direction
            const score = along + 3 * across;
            if (score < bestScore) { bestScore = score; best = id; }
        }
        if (best !== "") selectedId = best;
    }
    //---------------------------------------------------------- profiles
    // A profile is a saved configuration with a name: a file profiles/<name>.toml next to config.toml (the
    // default profile), in the same format, holding the settings and the tiles. Only one is in use; edits
    // go to its file. The name in use is kept in ~/.local/state/gona-launcher/profile, so a restart
    // comes back to it, and `open({"profile": "work"})` (a keybinding: `omarchy-shell shell summon
    // gona.launcher '{"profile":"work"}'`) switches to one. Switching writes the one being left, then loads
    // the other as an import does (what its file does not say goes back to the default; a file without
    // tiles keeps the ones on screen).
    property var profileNames: []
    // a short message drawn over the launcher for a moment (LauncherContent.qml), e.g. after a profile switch
    property string toast: ""
    Timer { id: toastTimer; interval: 1800; running: root.toast !== ""; onTriggered: root.toast = "" }
    property string profileMessage: ""
    property bool profileFailed: false
    function profileResult(message, failed) { profileMessage = message; profileFailed = failed; }
    // "default", "next" and "previous" mean something in a payload / the chips, so they are not names
    // At most this many profiles, the default one counting as the first (so four can be saved)
    readonly property int maxProfiles: 5
    readonly property bool profilesFull: profileNames.length + 1 >= maxProfiles
    // The buttons of the strip: names ("" = the default), the default first, then the saved ones by name;
    // none while the switch is off or nothing has been saved (a single profile is nothing to pick from)
    readonly property var profileButtons: showProfileButtons && profileNames.length > 0 ? [""].concat(profileNames).slice(0, maxProfiles) : []
    function profileLabel(index) {
        if (profileLabels === "letters") return "ABCDE".charAt(index);
        if (profileLabels === "roman") return ["I", "II", "III", "IV", "V"][index];
        return String(index + 1);
    }
    function validProfileName(name) { return /^[A-Za-z0-9_-]{1,32}$/.test(name) && ["default", "next", "previous"].indexOf(name) < 0; }
    // writes a file by its path, whatever the FileView in use points at (the text goes as an argument)
    function writeFile(path, text) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"", "sh", text, path]);
    }
    // ---- Super alone opens the launcher (⚙ > Keys, first row) ----------------------------------------
    // A plugin cannot bind keys itself, so this is a marked block in Hyprland's bindings.lua
    // (KeyCombo.withSuperMode()); the file is the only record of it, the same for every profile and never
    // in config.toml. It is written only with the person's consent: a switch on the first start's welcome screen
    // (`welcomeSuper`, on by default and worded to say what it does), or ⚙ > Keys later; loading the plugin never
    // touches bindings.lua. The `super-key` file in stateDir remembers the choice, so "Off" (or deleting the block by
    // hand) sticks. Nothing happens where there is no bindings.lua (not Omarchy, or the tests' throw-away HOME).
    readonly property string hyprBindings: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"
    property string superMode: "off"       // "off" | "tiles" | "allApps", as the file says
    property bool superAvailable: false    // there is a bindings.lua to write to
    function refreshSuperKey() {
        const text = readFile(hyprBindings);
        superAvailable = text.trim() !== "";
        superMode = KeyCombo.superModeOf(text);
        // a block that is already there is the person's choice: remember it (nothing is ever added here)
        if (superAvailable && superMode !== "off" && readFile(stateDir + "/super-key").trim() === "") writeFile(stateDir + "/super-key", superMode);
    }
    function setSuperMode(mode) {
        const text = readFile(hyprBindings);
        if (text.trim() === "") { superAvailable = false; return; }
        const next = KeyCombo.withSuperMode(text, mode);
        superMode = KeyCombo.superModeOf(next);
        writeFile(stateDir + "/super-key", superMode);
        if (next === text) return;
        // written, then Hyprland told to read it again, in one command (two execDetached race)
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && hyprctl reload >/dev/null", "sh", next, hyprBindings]);
    }
    function savedProfile() {
        const name = readFile(stateDir + "/profile").trim();
        return validProfileName(name) && readFile(profilePath(name)).trim() !== "" ? name : "";
    }
    Process {
        id: profileLister
        command: ["sh", "-c", "ls -1 \"$1\" 2>/dev/null", "sh", root.profilesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(f => f.endsWith(".toml")).map(f => f.slice(0, -5))
                                  .filter(n => root.validProfileName(n)).sort();
                // in the order they were made (the files have none): the state file's, then any it does not know
                const order = root.readFile(root.stateDir + "/profile-order").split("\n").filter(n => n !== "");
                root.profileNames = order.filter(n => found.indexOf(n) >= 0).concat(found.filter(n => order.indexOf(n) < 0));
            }
        }
    }
    function refreshProfiles() { profileLister.running = true; }
    // the saved profiles in the order they were made, remembered in stateDir/profile-order (the chips, the profile
    // buttons and Ctrl+P go in this order, so a profile made last comes last)
    function setProfiles(list) { profileNames = list; writeFile(stateDir + "/profile-order", list.join("\n")); }
    // leave the current profile (its file is written first) for `name` ("" = default)
    function switchProfile(name) {
        if (name === activeProfile) return true;
        if (name !== "" && (!validProfileName(name) || readFile(profilePath(name)).trim() === "")) {
            profileResult("There is no profile called \"" + name + "\"", true);
            return false;
        }
        const text = readFile(profilePath(name));
        if (name === "" && text.trim() === "") { profileResult("There is no default configuration to go back to", true); return false; }
        saveSize.stop();
        writeFile(configPath, configText()); // the one being left, by its own path
        const wasLoaded = configLoaded;
        const keepButtons = showProfileButtons, keepLabels = profileLabels; // shared by every profile, or the buttons would vanish
        configLoaded = false;                                               // with the first profile that does not have them
        activeProfile = name;
        const r = applyConfigText(text);
        showProfileButtons = keepButtons; profileLabels = keepLabels;
        configLoaded = wasLoaded;
        lastWritten = text;
        lastWriteTime = Date.now();
        writeFile(stateDir + "/profile", name);
        toast = "Profile: " + (name === "" ? "default" : name);
        profileResult(r.ok ? "Now using " + (name === "" ? "the default profile" : "\"" + name + "\"")
                           : "\"" + name + "\" is not valid TOML (" + r.message + "); using the defaults", !r.ok);
        return r.ok;
    }
    // save what is on screen as a new profile and use it from now on
    function createProfile(name) {
        if (!validProfileName(name)) { profileResult("A name is 1 to 32 letters, digits, - or _ (and not \"default\")", true); return false; }
        if (profileNames.indexOf(name) >= 0) { profileResult("There is already a profile called \"" + name + "\"", true); return false; }
        if (profilesFull) { profileResult("Up to " + maxProfiles + " profiles, the default included: delete one first", true); return false; }
        saveSize.stop();
        writeFile(configPath, configText());   // the one being left
        writeFile(profilePath(name), configText()); // the copy, which becomes the one in use
        activeProfile = name;
        lastWritten = configText();
        lastWriteTime = Date.now();
        writeFile(stateDir + "/profile", name);
        setProfiles(profileNames.concat([name]));
        profileResult("Saved as \"" + name + "\", now in use", false);
        return true;
    }
    // Same content under a new name; the one in use stays in use if it is the one renamed.
    function renameProfile(from, to) {
        if (!validProfileName(from) || profileNames.indexOf(from) < 0) { profileResult("Pick a saved profile to rename", true); return false; }
        if (!validProfileName(to)) { profileResult("A name is 1 to 32 letters, digits, - or _ (and not \"default\", \"next\", \"previous\")", true); return false; }
        if (to === from) return true;
        if (profileNames.indexOf(to) >= 0) { profileResult("There is already a profile called \"" + to + "\"", true); return false; }
        // one shell command, so the write of the profile in use lands before the move (two would race)
        const current = activeProfile === from;
        if (current) saveSize.stop();
        Quickshell.execDetached(["sh", "-c", "[ -n \"$3\" ] && printf '%s' \"$3\" > \"$1\"; mv -f \"$1\" \"$2\"; for e in .bak .broken; do [ -e \"$1$e\" ] && mv -f \"$1$e\" \"$2$e\"; done; true",
                                 "sh", profilePath(from), profilePath(to), current ? configText() : ""]);
        if (activeProfile === from) { activeProfile = to; lastWritten = configText(); lastWriteTime = Date.now(); writeFile(stateDir + "/profile", to); }
        setProfiles(profileNames.map(n => n === from ? to : n));
        profileResult("Renamed \"" + from + "\" to \"" + to + "\"", false);
        return true;
    }
    // the next (+1) or previous (-1) profile, default first, wrapping round; false when there is only the default
    function cycleProfile(delta) {
        const all = [""].concat(profileNames);
        if (all.length < 2) { profileResult("There is only the default profile; save another one first", true); toast = "Only the default profile"; return false; }
        const i = all.indexOf(activeProfile);
        return switchProfile(all[((i < 0 ? 0 : i) + delta + all.length) % all.length]);
    }
    function deleteProfile(name) {
        if (!validProfileName(name) || profileNames.indexOf(name) < 0) return false;
        if (activeProfile === name) { activeProfile = ""; const t = readFile(profilePath("")); saveSize.stop(); configLoaded = false; applyConfigText(t); configLoaded = true; lastWritten = t; lastWriteTime = Date.now(); writeFile(stateDir + "/profile", ""); }
        Quickshell.execDetached(["rm", "-f", profilePath(name), profilePath(name) + ".bak", profilePath(name) + ".broken"]);
        setProfiles(profileNames.filter(n => n !== name));
        profileResult("Deleted \"" + name + "\"", false);
        return true;
    }

    // ⚙ > Profiles > "Reset to factory settings": the launcher as on its first start. Everything in the configuration
    // folder is copied to <folder>.reset-<date> first, so nothing is lost for good; then the settings, tiles, profiles,
    // the profile in use and the usage counts are wiped and the welcome screen comes back (and, as on a first start,
    // Esc there starts with Omarchy). The Super binding is Hyprland's own file and stays as it is.
    function factoryReset() {
        saveSize.stop();
        usageSave.stop();
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        Quickshell.execDetached(["sh", "-c",
            "d=\"$1\"; [ -d \"$d\" ] && cp -a \"$d\" \"$d.reset-$2\"; rm -rf \"$d/profiles\" \"$d\"/config.toml \"$d\"/config.toml.*",
            "sh", configDir, stamp]);
        configLoaded = false;              // nothing below may schedule a save: the file stays gone until a preset is chosen
        resetAllSettings();
        layout = ({ type: "leaf", ids: [] });
        clearHistory();
        loadSettings();
        activeProfile = "";
        writeFile(stateDir + "/profile", "");
        setProfiles([]);
        clearUsage();
        lastWritten = "";
        lastWriteTime = Date.now();
        configLoaded = true;
        optionsOpen = false;
        tileMenuPath = null;
        welcomeIndex = 0;
        welcomeSaveOthers = false;
        welcomeSuper = true;
        welcomeFirstRun = true;
        welcomeOpen = true;
    }

    //---------------------------------------------------------- presets and the welcome screen
    // A preset is a ready-made configuration shipped with the plugin (app/presets/<name>.toml, see
    // lib/presets.js). Choosing one copies it into the profile in use, as an import does; the preset file is
    // never written. The welcome screen (launcher/Welcome.qml) offers them the first time the launcher runs
    // (no config.toml and nothing to migrate) and again from ⚙ > Profiles > "Show the welcome screen".
    readonly property string presetsDir: decodeURIComponent(Qt.resolvedUrl("presets").toString().replace(/^file:\/\//, ""))
    function presetText(name) { return Presets.find(name) ? readFile(presetsDir + "/" + name + ".toml") : ""; }
    property bool welcomeOpen: false
    property bool welcomeFirstRun: false  // shown because there is no configuration yet: Esc then starts with the recommended one
    property int welcomeIndex: 0          // the card chosen with the keyboard or a click
    property bool welcomeSaveOthers: false // also save the other presets as profiles
    property bool welcomeSuper: true       // the first start's switch: add Super alone to Hyprland's bindings.lua (consent, see refreshSuperKey)
    // how many of the other presets fit as new profiles (none that already exist by that name)
    function presetsToSave(name) {
        const room = maxProfiles - 1 - profileNames.length;
        return Presets.NAMES.filter(n => n !== name && profileNames.indexOf(n) < 0).slice(0, Math.max(0, room));
    }
    // what the welcome screen shows of each preset: its settings and tiles, and how many of its apps are installed
    readonly property var presetInfo: {
        if (!welcomeOpen) return [];
        DesktopEntries.applications.values; // re-evaluate once the desktop entries have loaded
        return Presets.LIST.map(p => {
            let r = { settings: {}, layout: null };
            try { r = Config.fromConfig(Toml.parse(presetText(p.name))); } catch (e) { /* shown as an empty preset */ }
            const tree = r.layout || { type: "leaf", ids: [] };
            const ids = [];
            walkLeaves(tree, leaf => ids.push(...leaf.ids));
            return Object.assign({}, p, { settings: r.settings, layout: tree, installed: ids.filter(id => DesktopEntries.byId(id)).length });
        });
    }
    function openWelcome() {
        optionsOpen = false;
        tileMenuPath = null;
        welcomeIndex = 0;
        welcomeSaveOthers = false;
        welcomeOpen = true;
    }
    // Puts preset `name` in place of the settings and tiles of the profile in use (the state before is kept
    // in <file>.bak, except on the first start, when there was none); with `saveOthers`, the other presets
    // are saved as profiles too, as many as there is room for.
    function applyPreset(name, saveOthers) {
        const text = presetText(name);
        if (text.trim() === "") { toast = "The ready-made profile \"" + name + "\" is missing"; return false; }
        if (!welcomeFirstRun) return addPresetProfile(name, text);
        // the first start: it becomes the default profile
        saveSize.stop();
        configLoaded = false;
        const r = applyConfigText(text);
        configLoaded = true;
        saveNow();
        if (saveOthers) {
            const others = presetsToSave(name);
            for (const other of others) writeFile(profilePath(other), presetText(other));
            setProfiles(profileNames.concat(others));
        }
        if (superAvailable) { // what the welcome screen's switch said (it was shown, on by default)
            if (!welcomeSuper) setSuperMode("off");
            else if (superMode === "off") setSuperMode("tiles");
        }
        welcomeOpen = false;
        welcomeFirstRun = false;
        toast = "Started with " + Presets.find(name).title;
        return r.ok;
    }
    // ⚙ > Profiles > "Add a ready-made profile": the preset becomes a new profile (named after it, "dock-2" if that is
    // taken) that is switched to; the profile in use and every other one stay exactly as they were.
    function uniqueProfileName(base) {
        let n = base, i = 2;
        while (profileNames.indexOf(n) >= 0) n = base + "-" + i++;
        return n;
    }
    function addPresetProfile(name, text) {
        if (profilesFull) { toast = "Profiles are full (" + maxProfiles + "): delete one first"; return false; }
        const pname = uniqueProfileName(name);
        const keepButtons = showProfileButtons, keepLabels = profileLabels; // shared by every profile
        saveSize.stop();
        writeFile(configPath, configText());                 // the one being left
        activeProfile = pname;                               // configPath is now the new profile's file
        writeFile(stateDir + "/profile", pname);
        configLoaded = false;
        const r = applyConfigText(text);
        showProfileButtons = keepButtons || profileNames.length === 0; // its first sibling: the buttons are how you reach them
        profileLabels = keepLabels;
        configLoaded = true;
        saveNow();
        setProfiles(profileNames.concat([pname]));
        welcomeOpen = false;
        toast = "Profile added: " + pname;
        return r.ok;
    }
    function closeWelcome() {
        if (welcomeFirstRun) applyPreset(Presets.LIST[0].name, false); // never left with nothing on screen
        else welcomeOpen = false;
    }
    // a key on the welcome screen: arrows and Tab choose, the digits 1.. too, Enter / Space start, Esc closes it
    function welcomeKey(event) {
        const n = Presets.LIST.length;
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_Up: case Qt.Key_Backtab: welcomeIndex = (welcomeIndex + n - 1) % n; return true;
        case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab: welcomeIndex = (welcomeIndex + 1) % n; return true;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: applyPreset(Presets.LIST[welcomeIndex].name, welcomeSaveOthers); return true;
        case Qt.Key_Escape: closeWelcome(); return true;
        }
        if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + n) { welcomeIndex = event.key - Qt.Key_1; return true; }
        return false;
    }

    //---------------------------------------------------------- usage: what has been launched
    // Every app launched from here is counted ({ n: times, last: when in ms }) in
    // ~/.local/state/gona-launcher/usage.json, on this machine only, so the all-apps list and the typed
    // search can put what is used most (or last) first. Off with `trackUsage` (nothing is counted, what
    // was counted stays until cleared); ⚙ > Search has the switch, the order and "Clear history". It is
    // state, not settings: it is not in config.toml and not part of Export.
    property var usageData: ({})
    readonly property string usagePath: stateDir + "/usage.json"
    FileView { id: usageFile; path: root.usagePath; blockLoading: true; watchChanges: false; printErrors: false }
    Timer { id: usageSave; interval: 1500; onTriggered: usageFile.setText(JSON.stringify(root.usageData)) }
    function loadUsage() {
        try {
            const d = JSON.parse(usageFile.text());
            const out = {};
            if (d && typeof d === "object") for (const id in d)
                if (d[id] && typeof d[id].n === "number" && d[id].n > 0) out[id] = { n: Math.floor(d[id].n), last: typeof d[id].last === "number" ? d[id].last : 0 };
            usageData = out;
        } catch (e) { usageData = ({}); }
    }
    function usageOf(id) { return usageData[id] || { n: 0, last: 0 }; }
    function noteLaunch(id) {
        if (!trackUsage || !id) return;
        const d = Object.assign({}, usageData);
        d[id] = { n: usageOf(id).n + 1, last: Date.now() };
        usageData = d;
        usageSave.restart();
    }
    function launchApp(entry) { noteLaunch(entry.id); entry.execute(); }
    function clearUsage() { usageData = ({}); usageFile.setText("{}"); usageSave.stop(); }
    readonly property int usageCount: Object.keys(usageData).length
    // The apps of the row above the tiles (⚙ > Search): the most launched, or the most recently launched
    // when that is the chosen order, at most `usageRowCount`; only installed apps that show in menus.
    readonly property var usageRowIds: {
        if (!showUsageRow) return [];
        DesktopEntries.applications.values; // re-evaluate once the desktop entries have loaded
        const byRecent = usageOrder === "recent";
        const ids = Object.keys(usageData).filter(id => { const e = DesktopEntries.byId(id); return e && !e.noDisplay; });
        ids.sort((a, b) => {
            const d = byRecent ? usageOf(b).last - usageOf(a).last : usageOf(b).n - usageOf(a).n;
            return d !== 0 ? d : DesktopEntries.byId(a).name.localeCompare(DesktopEntries.byId(b).name);
        });
        return ids.slice(0, usageRowCount);
    }
    // the room that row takes above the tiles (0 when it is off or there is nothing to show yet)
    readonly property real usageRowH: usageRowIds.length > 0 ? cellHeight(iconSize, searchLabels) + 16 : 0

    // Enter / Space: launch the selected app (or, while filtering, the first match)
    function launchSelected() {
        let e = selectedId !== "" ? DesktopEntries.byId(selectedId) : null;
        if (e && !matchesFilter(e)) e = null;
        if (!e && filterText !== "") e = firstMatch();
        if (!e) return false;
        launchApp(e);
        hide();
        return true;
    }
    // "Launch all" (per-tile, turned on in the tile menu): open every app in that tile at once
    function launchAllIn(path) {
        for (const id of leafAt(path).ids || []) {
            const e = DesktopEntries.byId(id);
            if (e) launchApp(e);
        }
        hide();
    }

    readonly property int matchCount: {
        filterText; DesktopEntries.applications.values; // re-evaluate when either changes
        return orderedVisibleIds().length;
    }

    //---------------------------------------------------------- dividers and crosses
    // Divider positions while dragging live here (path key -> ratio) and are written to the
    // layout once, on release, so the tiles are not rebuilt on every mouse move.
    property var live: ({})
    function key(path) { return JSON.stringify(path); }
    function ratioOf(path) {
        const v = live[key(path)];
        const n = nodeAt(layout, path);
        return v !== undefined ? v : (n ? n.ratio : 0.5);
    }
    // entries: [[path, ratio], ...], applied in a single assignment so bindings never see a
    // half-updated state (e.g. a cross that is briefly "unaligned" would hide the handle
    // being dragged and drop the drag)
    function setLiveMany(entries) {
        const l = Object.assign({}, live);
        for (const [path, r] of entries) l[key(path)] = Math.max(0.1, Math.min(0.9, r));
        live = l;
    }
    function setLive(path, r) { setLiveMany([[path, r]]); }
    function commitLive() {
        if (Object.keys(live).length === 0) return;
        const t = clone();
        for (const k in live) nodeAt(t, JSON.parse(k)).ratio = live[k];
        live = ({});
        commit(t);
    }

    // A "cross": a split whose two children are both splits in the other direction (a 2x2-like
    // junction). Its four line halves can be moved apart, but only one axis at a time: moving both
    // axes' halves independently would leave a hole between the tiles.
    readonly property real alignTol: 0.006
    readonly property real snapTol: 0.015
    function isCross(n) { return Tree.isCross(n); }
    // Same tiles, other orientation: rows-of-columns becomes columns-of-rows. Only valid when the
    // two children's dividers are aligned, which is when the halves of the *other* line are free.
    function rotateCross(path) {
        const t = clone();
        if (Tree.rotateCrossAt(t, path, alignTol)) commit(t);
    }
    // Roles: "V1"/"V2" = first/second half of the vertical line (top/bottom),
    //        "H1"/"H2" = first/second half of the horizontal line (left/right), "X" = the junction.
    function crossPress(path, role) {
        const n = nodeAt(layout, path);
        if (role === "X" || !isCross(n)) return;
        const ownAxis = n.dir === "v" ? "H" : "V"; // the line this split's own divider draws
        if (role[0] === ownAxis) rotateCross(path);  // free its halves by flipping the structure
    }
    function crossMove(path, role, fx, fy) {
        const n = nodeAt(layout, path);
        if (!isCross(n)) return;
        const ownAxis = n.dir === "v" ? "H" : "V";
        if (role === "X") { // move the whole junction: own line one way, both child lines the other
            const along = ownAxis === "H" ? fx : fy;
            setLiveMany([[path, ownAxis === "H" ? fy : fx],
                         [path.concat(["a"]), along], [path.concat(["b"]), along]]);
            return;
        }
        if (role[0] === ownAxis) return;
        const pos = role[0] === "V" ? fx : fy;
        const mine = role[1] === "1" ? "a" : "b";
        const other = role[1] === "1" ? "b" : "a";
        const otherPos = ratioOf(path.concat([other]));
        setLive(path.concat([mine]), Math.abs(pos - otherPos) < snapTol ? otherPos : pos); // snap to align
    }

    //---------------------------------------------------------- showing, hiding, sliding
    // edge: ""  = the centred, resizable card (the closest a plugin can get to the old floating OS
    //             window -- a plugin can only ever create layer-shell surfaces, never a real
    //             window the compositor lets you drag/resize by its own chrome, so this is a
    //             deliberate substitute, not the original thing);
    //       "top" | "bottom" | "left" | "right" = a panel docked to that screen edge that slides in;
    //       "full" = the whole screen, `offset` px away from every side (like a lightbox); how any of them come
    //       in is `effect`.
    property alias edge: saved.edge
    // The list of every installed app (Ctrl+A, the all-apps button, typing with "search all apps" on) takes the
    // whole screen whatever the mode: in a dock or a small window it would have no room. The launcher grows from
    // its own shape to the screen (and back) as `flip` goes 0 -> 1, the same window all along; `edge` itself does
    // not change. `grow` is how far it has grown (always 0 in full screen, which is already there).
    readonly property real grow: edge === "full" ? 0 : flip
    function lerp(a, b, t) { return a + (b - a) * t; }
    // The launcher's content area at its own size and at the whole screen: while it grows, the tiles keep the
    // first (they fade out, never re-laid out) and the list of apps is laid out at the second and scaled to
    // fit, so it zooms to its place instead of re-flowing on every frame (LauncherContent.qml).
    readonly property real ownContentW: edge === "" ? card.ownW
        : dockedArea.ownW - (edge === "left" || edge === "right" ? offset : (edge === "full" ? 2 * offset : 0))
    readonly property real ownContentH: edge === "" ? card.ownH
        : dockedArea.ownH - (edge === "top" || edge === "bottom" ? offset : (edge === "full" ? 2 * offset : 0))
    readonly property real fullContentW: (targetScreen ? targetScreen.width : 1920) - 2 * sharedOffset
    readonly property real fullContentH: (targetScreen ? targetScreen.height : 1080) - 2 * sharedOffset

    // Panel size, as % of the screen [width, height] and optionally the edge offset in px as a third
    // number, remembered separately for each edge (a top panel is wide and short, a side panel narrow
    // and tall), so switching between positions in ⚙ > Window never loses what was set for another
    // one. It is centred along its edge.
    property alias panels: saved.panels
    readonly property int panelW: panels[edge] ? panels[edge][0] : 100
    readonly property int panelH: panels[edge] ? panels[edge][1] : 50
    function setPanel(w, h) {
        if (!panels[edge]) return;
        const clamp = v => Math.max(5, Math.min(100, Math.round(v / 5) * 5));
        const p = Object.assign({}, panels);
        p[edge] = [clamp(w), clamp(h)].concat(panels[edge].length > 2 ? [panels[edge][2]] : []);
        panels = p;
    }
    readonly property var defaultPanels: ({ top: [100, 50], bottom: [100, 50], left: [40, 100], right: [40, 100] })
    // the saved sizes that are valid, over the defaults
    function loadPanels(stored) {
        const p = Object.assign({}, defaultPanels);
        for (const e of ["top", "bottom", "left", "right"]) {
            const v = stored && typeof stored === "object" ? stored[e] : undefined;
            if (Array.isArray(v) && v.length >= 2 && v[0] >= 5 && v[0] <= 100 && v[1] >= 5 && v[1] <= 100)
                p[e] = v.length > 2 && v[2] >= 0 && v[2] <= 200 ? [v[0], v[1], v[2]] : [v[0], v[1]];
        }
        panels = p;
    }

    // Gap (px) between the docked panel and the screen edge it slides from, so it does not sit
    // glued to the edge. Each docked edge keeps its own (third number of `panels[edge]`); until one is
    // set it follows the shared value (`sharedOffset`, also the one of full screen).
    property alias sharedOffset: saved.offset
    readonly property int offset: panels[edge] && panels[edge].length > 2 ? panels[edge][2] : sharedOffset
    readonly property bool offsetIsDefault: panels[edge] ? panels[edge].length < 3 : sharedOffset === defaults.offset
    function setOffset(v) {
        const o = Math.max(0, Math.min(200, Math.round(v / 4) * 4));
        if (!panels[edge]) { sharedOffset = o; return; }
        const p = Object.assign({}, panels);
        p[edge] = [panels[edge][0], panels[edge][1], o];
        panels = p;
    }
    function resetOffset() {
        if (!panels[edge]) { sharedOffset = defaults.offset; return; }
        const p = Object.assign({}, panels);
        p[edge] = [panels[edge][0], panels[edge][1]];
        panels = p;
    }

    // Slide speed, in ms (0 = instant). The default is a quick one.
    property alias slideSpeed: saved.speed
    function setSlideSpeed(v) { slideSpeed = Math.max(0, Math.min(2000, Math.round(v / 50) * 50)); }
    // The side "slide" and "meet" come from (top, bottom, left, right; meet: left/right = halves from both sides,
    // top/bottom = from above and below). A docked panel's slide always comes from its own edge.
    property alias fullFrom: saved.fullFrom
    // The opening effect: "classic" (a docked panel slides in with `slideSpeed`, full screen fades, a centred window
    // appears at once) or one of Fx.NAMES (fade, slide, meet, corners, blocks, fluid, bounce, genie, dissolve, glitch and
    // the terminal ones), which work the same in every mode: a shader over a frozen picture of the launcher, see
    // FxLayer.qml. Each has its own length (`effectMs`; `slideSpeed` is classic's).
    property alias effect: saved.effect
    property alias effectMs: saved.effectMs
    property alias closeAnim: saved.closeAnim // false: closing is instant (any effect, Classic too)
    readonly property bool fxOn: effect !== "classic"
    // Reduce motion: the launcher opens and closes at once, whatever the effect (an effect needs animMs > 0 to run)
    property alias reduceMotion: saved.reduceMotion
    readonly property int wantedMs: fxOn ? effectMs : slideSpeed // the length set in ⚙ > Effects, kept while motion is reduced
    readonly property int animMs: reduceMotion ? 0 : wantedMs
    function setEffectMs(v) { effectMs = Math.max(0, Math.min(2000, Math.round(v / 50) * 50)); }
    // the length ⚙ > Effects > Duration edits: the one of the effect in use
    function setAnimMs(v) { if (fxOn) setEffectMs(v); else setSlideSpeed(v); }
    function resetAnimMs() { resetSetting(fxOn ? "effectMs" : "speed"); }

    // `opened` is what the Omarchy shell drives through open()/close() (bottom of this file); the
    // generic `omarchy-shell shell toggle|summon|hide gona.launcher` commands call those for us.
    property bool opened: false
    onOpenedChanged: {
        // How long and with which curve `slide` goes to its new value is set here, before it is written: a binding
        // on `opened` in the animation itself may not have been re-read yet when the animation starts, and
        // would use the length of the direction it came from.
        slideAnim.duration = opened || closeAnim ? animMs : 0;
        slideAnim.easing.type = fxOn ? Easing.Linear : (opened ? Easing.OutCubic : Easing.InCubic);
        if (!opened) { resizeMode = false; optionsOpen = false; tileMenuPath = null; helpOpen = false; viewResetPending = true; }
        if (!opened && !welcomeFirstRun) welcomeOpen = false; // the first start's stays until a preset is chosen
        // take a fresh picture of the launcher for the shader effect on every open and close: the picture is not
        // live, so nothing else refreshes it, and one left from the previous close would show stale tiles
        if (fx.effect !== "") fx.snap();
        slide = opened ? 1 : 0; // last: with an instant close this is where onSlideChanged resets the view
    }
    // What the launcher shows (filter, selection, the all-apps view) goes back to the plain tiles
    // once it is fully hidden (slide at 0), not the moment it starts hiding, so the exit animation
    // keeps showing what was on screen instead of jumping to the unfiltered tiles. Opening again
    // before that (open()) does it first.
    property bool viewResetPending: false
    function resetView() { viewResetPending = false; allAppsOpen = false; filterText = ""; selectedId = ""; }
    onSlideChanged: {
        if (slide === 0 && viewResetPending) resetView();
    }

    // 0 = fully slid out, 1 = fully shown; the docked/full-screen panel is kept mapped while it is > 0
    property real slide: 0 // follows `opened`, set by onOpenedChanged above
    // In: fast start that settles (OutCubic). Out: starts gently and speeds up (InCubic), so the
    // panel leaves quickly instead of crawling through a long slow tail.
    // The shader effects bring their own curves (fx.js `ease`, springs that overshoot), so `slide` is linear then.
    Behavior on slide { NumberAnimation { id: slideAnim } }

    function hide() { opened = false; }

    // Which screen everything (the card or panel, the menus) opens on; set by open(), see focusedScreen().
    property var targetScreen: Quickshell.screens[0]
    property var anchorPos: null // where the bar button that opened the launcher is, on its screen: { x, y } or null
    // The monitor that has the focus in Hyprland (where the user is working), or the first one when
    // Hyprland does not say. Chosen each time the launcher opens from closed; never while it is open, since
    // changing a mapped window's screen would move it.
    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        const s = m ? Quickshell.screens.find(x => x.name === m.name) : undefined;
        return s || Quickshell.screens[0];
    }

    //---------------------------------------------------------- options menu (⚙) and tile menu (⋯)
    property bool optionsOpen: false
    onOptionsOpenChanged: {
        captureAction = ""; captureMessage = "";
        if (optionsOpen) tileMenuPath = null; // only one menu at a time
    }

    function toggleOptions() { optionsOpen = !optionsOpen; }
    // ? (or F1) lists the keyboard shortcuts on a card over the launcher (menus/Help.qml); any key or a click closes it
    property bool helpOpen: false
    // where the app `id` is (the path of its tile), or null
    function pathOfApp(id) {
        let found = null;
        (function walk(n, path) {
            if (found !== null) return;
            if (n.type === "leaf") { if (n.ids.indexOf(id) >= 0) found = path; }
            else { walk(n.a, path.concat(["a"])); walk(n.b, path.concat(["b"])); }
        })(layout, []);
        return found;
    }
    // Menu key / Shift+F10: the menu of the tile that holds the selected app (the first tile when nothing is selected),
    // so the tile menu is reachable without a mouse
    function openSelectedTileMenu() {
        const p = selectedId !== "" ? pathOfApp(selectedId) : null;
        openTileMenu(p !== null ? p : (function first(n, path) { return n.type === "leaf" ? path : first(n.a, path.concat(["a"])); })(layout, []));
    }

    // `tileMenuPath` is the tile being edited (or null).
    property var tileMenuPath: null
    function openTileMenu(path) {
        if (tileMenuPath !== null && key(tileMenuPath) === key(path)) { tileMenuPath = null; return; } // toggles
        tileMenuPath = path;
    }
    function closeTileMenu() { tileMenuPath = null; }
    onTileMenuPathChanged: { if (tileMenuPath !== null) optionsOpen = false; }
    // the tile being edited may vanish or change kind (split, removed, structure flipped): then close
    onLayoutChanged: {
        if (tileMenuPath !== null && leafAt(tileMenuPath).type !== "leaf") tileMenuPath = null;
    }
    // whichever of the two menus is open, if any -- both windows below yield exclusive keyboard
    // focus to the dedicated menu window while this is true, so only one surface ever claims it
    readonly property bool anyMenuOpen: optionsOpen || tileMenuPath !== null

    Component { id: contentC; LauncherContent { shell: root } }

    // ---- the one content window: the centred card (edge === "") and the docked/full-screen panel
    // (edge !== "") used to be two separate wlr layer-shell surfaces, each mapped only while its
    // mode was active. Changing `edge` while a menu was open then made the newly-mapped one land
    // on top of `menuWin` -- Hyprland stacks same-layer surfaces by mapping order, newest on top,
    // never by anything QML asks for (see the CLAUDE.md gotcha), and a surface that had been
    // invisible a moment ago is a fresh mapping. One window, always full-screen and already mapped
    // before any menu ever opens, cannot have that problem: switching `edge` just changes which
    // child Item is visible inside it, an ordinary scene change with no surface remapping at all.
    // The trade-off is that `card` and `dockedArea` size and position themselves (see `dockedArea`'s
    // anchors/width/height below) instead of the window doing it, since only "full" can still use
    // the simple four-edges-anchored trick without also fighting an explicit width/height.
    PanelWindow {
        id: launcherWin
        screen: root.targetScreen
        visible: root.opened || root.slide > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "gona-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (root.opened && !root.anyMenuOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore // slide over the other windows, do not push them

        // a click on the bare screen closes the launcher (and, since `card`/`dockedArea` swallow
        // their own clicks, this only ever fires for a click that really is outside everything)
        MouseArea { anchors.fill: parent; onClicked: root.hide() }

        Item {
            id: card
            visible: root.edge === "" && !root.welcomeOpen
            // its own size, centred; growing to the whole screen (less the offset) with `grow`
            readonly property real ownW: Math.min(Math.max(root.winW, root.minWinW), root.screenLimit("width"))
            readonly property real ownH: Math.min(Math.max(root.winH, root.minWinH), root.screenLimit("height"))
            x: root.lerp((parent.width - ownW) / 2, root.sharedOffset, root.grow)
            y: root.lerp((parent.height - ownH) / 2, root.sharedOffset, root.grow)
            width: root.lerp(ownW, parent.width - 2 * root.sharedOffset, root.grow)
            height: root.lerp(ownH, parent.height - 2 * root.sharedOffset, root.grow)

            // swallow clicks on empty space inside the launcher so they do not fall through to the
            // screen-wide MouseArea above and close everything
            MouseArea { anchors.fill: parent; onClicked: {} }

            Item { // what an opening effect draws (FxLayer): the background, the tiles and the grip
                id: cardStage
                anchors.fill: parent
                Rectangle { // the card's background: the app background colour, with its own opacity
                    anchors.fill: parent
                    radius: root.corner
                    color: root.bgColor
                }
                Item {
                    anchors.fill: parent
                    clip: true
                    // `focus` only while this is the mode in use: two Loaders with `focus: true` in one window
                    // compete, and the hidden one (the centred card while docked, or the reverse) kept the
                    // keyboard, so Esc, arrows and typing reached nothing
                    Loader { anchors.fill: parent; focus: root.edge === "" && !root.welcomeOpen; active: root.edge === ""; sourceComponent: contentC }
                }

                // resize grip: drags winW/winH, the same size a floating OS window used to keep before
                // this became an overlay plugin (never below the tiles' own minimum, see minWinW/minWinH).
                // Bottom-LEFT corner, not bottom-right: the ⚙ options button already lives in the
                // bottom-right of the footer (LauncherContent.qml), faint until hovered, and a grip there
                // would sit on top of its click area.
                Item {
                    id: grip
                    anchors { left: parent.left; bottom: parent.bottom }
                    width: 16; height: 16
                    opacity: gripHover.hovered || gripDrag.active ? 0.8 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    HoverHandler { id: gripHover; cursorShape: Qt.SizeBDiagCursor }
                    Text { anchors.fill: parent; text: "◣"; color: root.dim; font.pixelSize: 13
                           horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignBottom }
                    DragHandler {
                        id: gripDrag
                        target: null
                        onCentroidChanged: {
                            if (!active) return;
                            root.winW = Math.round(card.width - (centroid.position.x - centroid.pressPosition.x));
                            root.winH = Math.round(card.height + centroid.position.y - centroid.pressPosition.y);
                        }
                    }
                }
            } // cardStage
        }

        // docked panel (edge = top/bottom/left/right) and full screen (edge = "full"). Anchored to
        // its edge only (one anchor line per axis, never two, so it never conflicts with the
        // explicit width/height below) and centred along the other axis; width and height are % of
        // the screen. "full" is the one case that anchors two opposite edges (top+left) with an
        // explicit size rather than all four, for the same reason: anchoring all four would leave
        // nothing for the explicit size to mean.
        Item {
            id: dockedArea
            visible: root.edge !== "" && !root.welcomeOpen
            readonly property bool vertical: root.edge === "left" || root.edge === "right"
            // Placed with x / y, not anchors: switching `edge` re-evaluates each anchor on its own, and for
            // an instant the old and the new edge were both anchored (top and bottom, say), which makes
            // Qt stretch the item between them and leaves its height stuck at the whole screen, deaf to
            // `panelH` from then on (that is what "Panel height does not work after changing the
            // position" was). Plain coordinates have no such in-between state.
            // Full screen leaves 1 px on the left as a distinguishing mark for anyone probing window
            // geometry (kept from the old build; harmless either way now that nothing greps for it).
            // along its edge the panel is centred, or (nextToBar, opened from the bar button) centred on the button
            readonly property bool atButton: root.nextToBar && root.anchorPos !== null
            readonly property real ownX: root.edge === "left" ? 0
               : (root.edge === "right" ? parent.width - ownW
               : (root.edge === "full" ? 1 : (atButton && !vertical ? Math.max(0, Math.min(parent.width - ownW, root.anchorPos.x - ownW / 2)) : (parent.width - ownW) / 2)))
            readonly property real ownY: root.edge === "top" || root.edge === "full" ? 0
               : (root.edge === "bottom" ? parent.height - ownH
               : (atButton && vertical ? Math.max(0, Math.min(parent.height - ownH, root.anchorPos.y - ownH / 2)) : (parent.height - ownH) / 2))
            readonly property real ownW: root.edge === "full"
                 ? (root.targetScreen ? root.targetScreen.width - 1 : 1365)
                 : (root.targetScreen ? Math.round(root.targetScreen.width * root.panelW / 100) : 1000) + (vertical ? root.offset + root.powerPad : 0)
            readonly property real ownH: root.edge === "full"
                  ? (root.targetScreen ? root.targetScreen.height : 768)
                  : (root.targetScreen ? Math.round(root.targetScreen.height * root.panelH / 100) : 600) + (vertical ? 0 : root.offset + root.powerPad)
            // growing to the whole screen with `grow` (all apps), from its own place and size
            x: root.lerp(ownX, 0, root.grow)
            y: root.lerp(ownY, 0, root.grow)
            width: root.lerp(ownW, parent.width, root.grow)
            height: root.lerp(ownH, parent.height, root.grow)

        Item { // the launcher slides in from its edge inside a fixed, transparent area
            id: mover
            anchors.fill: parent
            // Classic: a docked panel slides in from its edge, full screen fades, a centred window has nothing to do
            readonly property string from: root.fxOn || root.edge === "full" ? "" : root.edge
            x: from === "left" ? -(1 - root.slide) * width : (from === "right" ? (1 - root.slide) * width : 0)
            y: from === "top" ? -(1 - root.slide) * height : (from === "bottom" ? (1 - root.slide) * height : 0)
            opacity: !root.fxOn && root.edge === "full" ? root.slide : 1

            // a click in the gap is a click outside the launcher
            MouseArea { anchors.fill: parent; onPressed: root.hide() }

            Item { // everything that is shown
                id: stage
                anchors.fill: parent
                Loader {
                    anchors {
                        fill: parent
                        // the gap to the screen edge: on its own edge, and on every side as it grows to the screen
                        topMargin: root.lerp(root.edge === "top" || root.edge === "full" ? root.offset : 0, root.sharedOffset, root.grow)
                        bottomMargin: root.lerp(root.edge === "bottom" || root.edge === "full" ? root.offset : 0, root.sharedOffset, root.grow)
                        leftMargin: root.lerp(root.edge === "left" || root.edge === "full" ? root.offset : 0, root.sharedOffset, root.grow)
                        rightMargin: root.lerp(root.edge === "right" || root.edge === "full" ? root.offset : 0, root.sharedOffset, root.grow)
                    }
                    focus: root.edge !== "" && !root.welcomeOpen // a Loader is a focus scope; without this the content gets no key events (see the card's Loader above)
                    active: root.edge !== ""
                    sourceComponent: contentC
                }
            }
        }
        } // dockedArea

        // the first start (and ⚙ > Profiles > "Show the welcome screen"): the presets to choose from, in place of
        // the launcher, centred on the screen whatever the mode
        Help {
            anchors.centerIn: parent
            shell: root
            visible: root.helpOpen && !root.welcomeOpen
            z: 50
        }
        Welcome {
            id: welcome
            anchors.centerIn: parent
            shell: root
            visible: root.welcomeOpen
            focus: root.welcomeOpen
        }

        // the opening / closing effect (⚙ > Effects) over whichever of the two is showing
        FxLayer {
            id: fx
            anchors.fill: parent
            effect: root.fxOn && root.animMs > 0 ? root.effect : ""
            t: root.slide
            opening: root.opened
            target: root.edge === "" ? cardStage : stage
            srcRect: root.edge === "" ? Qt.rect(card.x, card.y, card.width, card.height)
                                      : Qt.rect(dockedArea.x, dockedArea.y, dockedArea.width, dockedArea.height)
            bodyRect: {
                if (root.edge === "") return srcRect;
                const b = Fx.bodyOf(root.edge, { x: srcRect.x, y: srcRect.y, w: srcRect.width, h: srcRect.height }, root.offset);
                return Qt.rect(b.x, b.y, b.w, b.h);
            }
            edge: root.edge
            from: root.fullFrom
            anchor: root.anchorPos
        }
    }

    // ---- options menu (⚙) and tile menu (⋯): one dedicated overlay surface, independent of
    // whichever content the window above is showing (`card` or `dockedArea`), so either menu works
    // the same way in every mode. It covers the whole screen but is transparent and, like the old
    // per-menu MenuWindow, only the menu itself receives the pointer (`mask`): a click anywhere else
    // passes straight through to whatever is behind it. Landing on the launcher, that is
    // LauncherContent's own z:35 MouseArea, which closes just the menu; landing on bare screen, the
    // window above's own scrim, which closes everything. Without the mask this window would sit in
    // front of the tiles the whole time a menu is open and swallow every click meant for them --
    // dragging dividers, launching an app, even the scrim -- which is a menu that opens once and
    // never lets go rather than one you can still work behind.
    PanelWindow {
        id: menuWin
        screen: root.targetScreen
        visible: root.anyMenuOpen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "gona-launcher-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.anyMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: root.tileMenuPath !== null ? tileMenu : floatingMenu }

        // both menus stay centred on the whole screen until dragged by their own header strip
        // (OptionsMenu.qml / TileMenu.qml), same as when they were their own window.
        OptionsMenu {
            id: floatingMenu
            shell: root
            open: root.optionsOpen
            maxHeight: menuWin.height * 0.9 / root.menuScale
        }
        Binding {
            when: floatingMenu.visible && !floatingMenu.userMoved
            target: floatingMenu; property: "x"; value: (menuWin.width - floatingMenu.width) / 2
            restoreMode: Binding.RestoreNone
        }
        Binding {
            when: floatingMenu.visible && !floatingMenu.userMoved
            target: floatingMenu; property: "y"; value: (menuWin.height - floatingMenu.height) / 2
            restoreMode: Binding.RestoreNone
        }

        TileMenu {
            id: tileMenu
            shell: root
            visible: root.tileMenuPath !== null
            maxHeight: menuWin.height * 0.9 / root.menuScale
        }
        Binding {
            when: tileMenu.visible && !tileMenu.userMoved
            target: tileMenu; property: "x"; value: (menuWin.width - tileMenu.width) / 2
            restoreMode: Binding.RestoreNone
        }
        Binding {
            when: tileMenu.visible && !tileMenu.userMoved
            target: tileMenu; property: "y"; value: (menuWin.height - tileMenu.height) / 2
            restoreMode: Binding.RestoreNone
        }
    }

    //---------------------------------------------------------- plugin lifecycle
    // Called by the Omarchy shell (see manifest.json): `omarchy-shell shell summon gona.launcher
    // '{"allApps":true}'` opens straight into "all apps" (the old Super-alone shortcut);
    // `'{"options":true}'` (the bar button's right click) opens the ⚙ menu together with the tiles,
    // not on its own -- a setting with no tiles behind it to preview against (icon size, colours,
    // ...) is not very useful, and there is no in-launcher ⚙ button any more to reach it once it is
    // already open (see LauncherContent.qml), only this right click and its keybind (⚙ > Keys).
    // Plain `summon`/`toggle` with no payload just opens the tiles. `hide`/`toggle` call close().
    // `{"reload":true}` (the bar button's right-click menu): everything is read from disk again, as if the launcher had
    // just started: the profile in use, the usage counts, the profile list, the Omarchy theme and the Super binding.
    // A config.toml that is not valid TOML is refused and the current settings stay.
    function reloadAll() {
        let message = "Reloaded from disk";
        const text = readFile(configPath);
        if (text.trim() !== "") {
            saveSize.stop();
            configLoaded = false;
            const r = applyConfigText(text);
            configLoaded = true;
            if (r.ok) { lastWritten = text; lastWriteTime = Date.now(); }
            else message = "The configuration is not valid TOML (" + r.message + "); kept the current settings";
        }
        loadUsage();
        refreshProfiles();
        refreshOmarchy();
        refreshSuperKey();
        toast = message;
    }
    function open(payload) {
        var args = {};
        if (payload) { try { args = JSON.parse(payload) || {}; } catch (e) { args = {}; } }
        // `opened` first, deliberately: `launcherWin` and `menuWin` are separate wlr layer-shell
        // surfaces, and Hyprland stacks same-layer surfaces in mapping order (newest on top) rather
        // than anything QML asks for -- setting `optionsOpen` (which maps menuWin) after `opened`
        // (which maps launcherWin) is what keeps the menu on top when both open together.
        refreshOmarchy();
        refreshSuperKey(); // bindings.lua may have been edited by hand since
        if (args.profile !== undefined) {
            const p = String(args.profile);
            if (p === "next" || p === "previous") cycleProfile(p === "next" ? 1 : -1);
            else switchProfile(p === "default" ? "" : p);
        }
        // `{"anchor":{"x":..,"y":..,"screen":"eDP-1"}}` (sent by the bar button) says where the button is: with
        // `nextToBar` a panel docked to an edge is centred there along its edge, and it opens on that screen
        anchorPos = args.anchor && typeof args.anchor.x === "number" && typeof args.anchor.y === "number" ? { x: args.anchor.x, y: args.anchor.y } : null;
        if (!opened) {
            const named = args.anchor && args.anchor.screen ? Quickshell.screens.find(x => x.name === args.anchor.screen) : undefined;
            targetScreen = named || focusedScreen();
        }
        if (args.reload === true || args.reload === "true") reloadAll();
        opened = true;
        if (args.allApps === true || args.allApps === "true") allAppsOpen = true;
        if (args.options === true || args.options === "true" || args.tab !== undefined) optionsOpen = true;
        if (args.presets === true || args.presets === "true") openWelcome(); // `{"presets":true}`: the welcome screen's presets
        // `{"profile":"work"}` switches to that profile first ("default" for config.toml, "next" / "previous"
        // to cycle), see "profiles"
        // `{"tab":"colors"}` opens the ⚙ menu on that tab (tiles, colors, window, effects, search, buttons, keys,
        // menu, profiles), for a keybinding straight to one tab and for checking a tab without clicking; the old
        // "appearance" (split into Menu and Profiles) opens Profiles
        if (args.tab !== undefined) {
            const want = String(args.tab) === "appearance" ? "profiles" : String(args.tab);
            const i = floatingMenu.tabs.findIndex(t => t.key === want);
            if (i >= 0) floatingMenu.tab = i;
        }
    }
    function close() { opened = false; }
}
